/*
 * touch_multi.c - 统计触摸屏的"同时在屏触点数"与上报频率
 *
 * 用途：验证多点触控驱动是否真的支持 5 点、有没有丢点。
 * 按 Multi-touch Type B 协议解析：ABS_MT_SLOT 选槽位，
 * ABS_MT_TRACKING_ID = -1 表示该手指抬起。
 *
 * 用法：touch_multi <事件设备> [观察秒数]
 * 例：  touch_multi /dev/input/event2 15
 *
 * 交叉编译：
 *   arm-linux-gnueabihf-gcc -static -O2 -o touch_multi touch_multi.c
 */

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <linux/input.h>

#define MAX_SLOTS 16

static double now_sec(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(int argc, char **argv)
{
	const char *dev = (argc > 1) ? argv[1] : "/dev/input/event2";
	int seconds = (argc > 2) ? atoi(argv[2]) : 15;
	int slots[MAX_SLOTS];
	int slot = 0;
	int max_points = 0;
	int max_slot_used = 0;
	int x_min = 100000, x_max = -1, y_min = 100000, y_max = -1;
	long events = 0;
	long syn_events = 0;
	double t0, t1;
	int fd;

	memset(slots, 0, sizeof(slots));

	fd = open(dev, O_RDONLY | O_NONBLOCK);
	if (fd < 0) {
		fprintf(stderr, "打开 %s 失败: %s\n", dev, strerror(errno));
		return 1;
	}

	printf("%s: 观察 %d 秒，请在屏上依次用 1~5 根手指按住并移动…\n",
	       dev, seconds);

	t0 = now_sec();

	while (1) {
		struct pollfd pfd;
		int ready;

		t1 = now_sec();
		if (t1 - t0 >= seconds)
			break;

		pfd.fd = fd;
		pfd.events = POLLIN;

		ready = poll(&pfd, 1, 200);
		if (ready <= 0)
			continue;

		for (;;) {
			struct input_event ev;
			ssize_t n = read(fd, &ev, sizeof(ev));
			int active = 0;
			int i;

			if (n < (ssize_t)sizeof(ev))
				break;

			events++;

			if (ev.type == EV_ABS) {
				switch (ev.code) {
				case ABS_MT_SLOT:
					if (ev.value >= 0 && ev.value < MAX_SLOTS)
						slot = ev.value;
					if (slot > max_slot_used)
						max_slot_used = slot;
					break;
				case ABS_MT_TRACKING_ID:
					if (slot < MAX_SLOTS)
						slots[slot] = (ev.value >= 0);
					break;
				case ABS_MT_POSITION_X:
					if (ev.value < x_min) x_min = ev.value;
					if (ev.value > x_max) x_max = ev.value;
					break;
				case ABS_MT_POSITION_Y:
					if (ev.value < y_min) y_min = ev.value;
					if (ev.value > y_max) y_max = ev.value;
					break;
				default:
					break;
				}
			} else if (ev.type == EV_SYN) {
				syn_events++;

				for (i = 0; i < MAX_SLOTS; i++) {
					if (slots[i])
						active++;
				}

				if (active > max_points)
					max_points = active;
			}
		}
	}

	t1 = now_sec();
	close(fd);

	printf("\n=== 结果 ===\n");
	printf("观察时长      : %.1f s\n", t1 - t0);
	printf("最大同时触点  : %d 点\n", max_points);
	printf("用到最大槽位  : %d（0 基）\n", max_slot_used);
	printf("触摸事件总数  : %ld 条，其中同步帧 %ld 条（约 %.1f 帧/秒）\n",
	       events, syn_events, syn_events / (t1 - t0));
	if (x_max >= 0)
		printf("X 坐标范围    : %d ~ %d\n", x_min, x_max);
	if (y_max >= 0)
		printf("Y 坐标范围    : %d ~ %d\n", y_min, y_max);

	return 0;
}
