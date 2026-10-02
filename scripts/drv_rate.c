/*
 * drv_rate.c - 测量字符设备驱动“在固定时间内最多能被读多少次”
 *
 * 用途：验证驱动是否正确实施了传感器协议要求的采样间隔。
 * 例如 DHT11 要求 >=1s、HC-SR04 要求 >=60ms，驱动若不加限制，
 * 本工具会在同样时间内读到远多于协议允许的次数。
 *
 * 用法：drv_rate <设备节点> [单次读取字节数] [测试秒数]
 * 例：  drv_rate /dev/dht11 12 5
 *
 * 交叉编译：
 *   arm-linux-gnueabihf-gcc -static -O2 -o drv_rate drv_rate.c
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static double now_sec(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(int argc, char **argv)
{
	const char *dev;
	int size, secs;
	unsigned char buf[512];
	int fd, ok = 0, fail = 0, eof = 0;
	double t0, t1;
	int last_errno = 0;

	if (argc < 2) {
		fprintf(stderr, "用法: %s <设备节点> [读取字节数] [测试秒数]\n", argv[0]);
		return 1;
	}

	dev = argv[1];
	size = (argc > 2) ? atoi(argv[2]) : 32;
	secs = (argc > 3) ? atoi(argv[3]) : 5;

	if (size <= 0 || size > (int)sizeof(buf)) {
		fprintf(stderr, "读取字节数需在 1..%zu 之间\n", sizeof(buf));
		return 1;
	}

	fd = open(dev, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "打开 %s 失败: %s\n", dev, strerror(errno));
		return 1;
	}

	t0 = now_sec();
	t1 = t0 + secs;
	while (now_sec() < t1) {
		ssize_t n = read(fd, buf, size);

		if (n == 0) {
			/*
			 * 部分驱动（如 sr04）在 read 里用 *ppos 做了一次性读保护，
			 * 同一个 fd 第二次读会返回 0。这里重新打开以重置 ppos，
			 * 但不把它计入“成功采样”，否则会虚增测量次数。
			 */
			eof++;
			close(fd);
			fd = open(dev, O_RDONLY);
			if (fd < 0) {
				fprintf(stderr, "重新打开 %s 失败: %s\n",
					dev, strerror(errno));
				return 1;
			}
		} else if (n < 0) {
			fail++;
			last_errno = errno;
		} else {
			ok++;
		}
	}
	t1 = now_sec();

	printf("%s: %.3fs 内成功采样 %d 次、失败 %d 次（EOF 重开 %d 次）\n",
	       dev, t1 - t0, ok, fail, eof);
	if (ok > 0)
		printf("  平均 %.1f ms/次，约 %.1f 次/秒\n",
		       (t1 - t0) * 1000.0 / ok, ok / (t1 - t0));
	if (fail && last_errno)
		printf("  最后一次失败原因: %s\n", strerror(last_errno));

	close(fd);
	return 0;
}
