/*
 * sensor_lat.c - 测量字符设备 ioctl/read 的单次阻塞时长
 *
 * 用途：量化"在 GUI 线程里直接读传感器"的代价。
 * 本板首页（HomePage::updateEnvironment）就在 GUI 线程里 open+ioctl
 * /dev/dht11，而 DHT11 驱动内部有 msleep(18) 时序和 1s 最小间隔保护，
 * 单次调用最坏能把界面线程卡住接近 1 秒。
 *
 * 用法：sensor_lat <设备节点> [次数] [间隔毫秒]
 * 例：  sensor_lat /dev/dht11 5 1200
 *
 * 默认按 DHT11 的 DHT11_IOC_GET_MEASUREMENT 发送 ioctl（见
 * include/uapi/linux/smarthome_dht11.h），其它设备可自行改这条命令。
 *
 * 交叉编译：
 *   arm-linux-gnueabihf-gcc -static -O2 -o sensor_lat sensor_lat.c
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include "smarthome_dht11.h"

static double now_ms(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

int main(int argc, char **argv)
{
	const char *dev;
	int rounds = 5;
	int gap_ms = 1200;
	double worst = 0.0;
	double total = 0.0;
	int ok = 0;
	int i;

	if (argc < 2) {
		fprintf(stderr,
			"用法: %s <设备节点> [次数] [间隔毫秒]\n", argv[0]);
		return 1;
	}

	dev = argv[1];
	if (argc > 2)
		rounds = atoi(argv[2]);
	if (argc > 3)
		gap_ms = atoi(argv[3]);

	printf("%s: 共 %d 次，每次间隔 %dms\n", dev, rounds, gap_ms);

	for (i = 0; i < rounds; i++) {
		struct dht11_measurement measurement;
		double t0, t1, cost;
		int fd, ret;

		fd = open(dev, O_RDONLY);
		if (fd < 0) {
			fprintf(stderr, "第 %d 次: open 失败: %s\n",
				i + 1, strerror(errno));
			return 1;
		}

		memset(&measurement, 0, sizeof(measurement));

		t0 = now_ms();
		ret = ioctl(fd, DHT11_IOC_GET_MEASUREMENT, &measurement);
		t1 = now_ms();

		close(fd);

		cost = t1 - t0;
		total += cost;
		if (cost > worst)
			worst = cost;
		ok++;

		printf("  第 %d 次: open+ioctl+close 耗时 %.1f ms"
		       "（ioctl 返回 %d, valid=%u, %u.%u℃ %u.%u%%）\n",
		       i + 1, cost, ret,
		       measurement.valid,
		       measurement.temperature_integer,
		       measurement.temperature_decimal,
		       measurement.humidity_integer,
		       measurement.humidity_decimal);

		if (i + 1 < rounds) {
			struct timespec ts;

			ts.tv_sec = gap_ms / 1000;
			ts.tv_nsec = (long)(gap_ms % 1000) * 1000000L;
			nanosleep(&ts, NULL);
		}
	}

	if (ok > 0)
		printf("统计: 平均 %.1f ms，最大 %.1f ms\n",
		       total / ok, worst);

	return 0;
}
