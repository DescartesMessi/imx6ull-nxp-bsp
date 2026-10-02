/*
 * uart_loopback.c - 串口控制器内部回环自测
 *
 * 通过 TIOCM_LOOP 打开 UART 控制器内部的 TX->RX 回环，写入一段数据再读回，
 * 用于验证串口控制器的收发通路是否正常。
 *
 * 注意：内部回环绕过了板上的电平转换/收发器（如 SP3232、SP3485），
 * 只覆盖控制器本身的收发逻辑；物理层验证仍需外部回环或对端设备。
 *
 * 用法：uart_loopback <设备节点> [波特率]
 * 例：  uart_loopback /dev/ttymxc2 9600
 *
 * 交叉编译：
 *   arm-linux-gnueabihf-gcc -static -O2 -o uart_loopback uart_loopback.c
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <termios.h>
#include <unistd.h>

/* glibc 的 termios.h 不导出这个 Linux 专有位，按内核 uapi 补上 */
#ifndef TIOCM_LOOP
#define TIOCM_LOOP 0x8000
#endif

/*
 * 无论测试成功与否都要清掉 TIOCM_LOOP。
 * 否则该串口会一直处于内部回环状态：输出被自己收回来。若正好是控制台，
 * 会形成自问自答的死循环刷屏，把 shell 冲垮。
 */
static void clear_loopback(int fd)
{
	int mctrl;

	if (ioctl(fd, TIOCMGET, &mctrl) == 0) {
		mctrl &= ~TIOCM_LOOP;
		ioctl(fd, TIOCMSET, &mctrl);
	}
}

static int set_baud(int fd, int baud)
{
	struct termios tio;
	speed_t sp;

	switch (baud) {
	case 9600:   sp = B9600;   break;
	case 19200:  sp = B19200;  break;
	case 38400:  sp = B38400;  break;
	case 57600:  sp = B57600;  break;
	case 115200: sp = B115200; break;
	default:     return -1;
	}

	if (tcgetattr(fd, &tio) < 0)
		return -1;
	cfmakeraw(&tio);
	cfsetispeed(&tio, sp);
	cfsetospeed(&tio, sp);
	return tcsetattr(fd, TCSANOW, &tio);
}

int main(int argc, char **argv)
{
	const char *dev;
	int baud, fd, mctrl, ret;
	char tx[16], rx[16];
	fd_set rfds;
	struct timeval tv;
	ssize_t n;

	if (argc < 2) {
		fprintf(stderr, "用法: %s <设备节点> [波特率]\n", argv[0]);
		return 1;
	}
	dev = argv[1];
	baud = (argc > 2) ? atoi(argv[2]) : 115200;

	fd = open(dev, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (fd < 0) {
		fprintf(stderr, "打开 %s 失败: %s\n", dev, strerror(errno));
		return 1;
	}
	if (set_baud(fd, baud) < 0) {
		fprintf(stderr, "设置波特率 %d 失败: %s\n", baud, strerror(errno));
		close(fd);
		return 1;
	}

	/* 保留原有调制解调器控制位，额外打开内部回环 */
	if (ioctl(fd, TIOCMGET, &mctrl) < 0) {
		fprintf(stderr, "TIOCMGET 失败: %s\n", strerror(errno));
		close(fd);
		return 1;
	}
	mctrl |= TIOCM_LOOP;
	if (ioctl(fd, TIOCMSET, &mctrl) < 0) {
		fprintf(stderr, "设置 TIOCM_LOOP 失败: %s\n", strerror(errno));
		close(fd);
		return 1;
	}

	strcpy(tx, "UART-LOOPBACK");
	ret = write(fd, tx, strlen(tx));
	if (ret < 0) {
		fprintf(stderr, "写入失败: %s\n", strerror(errno));
		clear_loopback(fd);
		close(fd);
		return 1;
	}

	FD_ZERO(&rfds);
	FD_SET(fd, &rfds);
	tv.tv_sec = 2;
	tv.tv_usec = 0;
	ret = select(fd + 1, &rfds, NULL, NULL, &tv);
	if (ret <= 0) {
		printf("%s: 回环失败，2 秒内未收到自己的发送内容\n", dev);
		clear_loopback(fd);
		close(fd);
		return 2;
	}

	memset(rx, 0, sizeof(rx));
	n = read(fd, rx, sizeof(rx) - 1);
	if (n <= 0) {
		printf("%s: 回环失败，读取错误: %s\n", dev, strerror(errno));
		clear_loopback(fd);
		close(fd);
		return 2;
	}

	if (strcmp(tx, rx) == 0)
		printf("%s: 回环成功 (发送 %zu 字节, 收到 %zd 字节: \"%s\")\n",
		       dev, strlen(tx), n, rx);
	else
		printf("%s: 回环数据不一致: 发送 \"%s\" 收到 \"%s\"\n", dev, tx, rx);

	clear_loopback(fd);
	close(fd);
	return 0;
}
