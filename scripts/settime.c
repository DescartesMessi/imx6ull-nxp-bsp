/*
 * settime.c - 设置/查看系统时间并同步到 RTC
 *
 * 背景：本板 busybox 没有编译 date applet，hwclock 也不支持 --set，
 * 因此板上既没有命令能改时间，也没有命令能打印时间，只能自己
 * 调用 settimeofday() / localtime_r()。
 *
 * 用法：
 *   settime --epoch <秒>          用 Unix 时间戳设置（推荐，无时区歧义）
 *   settime --show               打印当前 UTC / 本地 / RTC 时间
 *   settime <年> <月> <日> <时> <分> <秒>
 *                                按本地时区解释后设置
 *
 * 例：
 *   settime --epoch 1790860000
 *   settime 2026 10 01 20 35 00
 *
 * 交叉编译：
 *   arm-linux-gnueabihf-gcc -static -O2 -o settime settime.c
 *
 * 说明：RTC 寄存器按 UTC 解释，因此同步给 /dev/rtc0 的是 UTC 时间；
 * 本地时间由 /etc/localtime + TZ 决定（本板为 CST-8，即 UTC+8）。
 */

#include <fcntl.h>
#include <linux/rtc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* 把 time_t 同步写入 /dev/rtc0（内核按 UTC 解释 RTC 寄存器） */
static void sync_rtc(time_t t)
{
	struct rtc_time rt;
	struct tm utc;
	int fd;

	if (gmtime_r(&t, &utc) == NULL) {
		fprintf(stderr, "gmtime_r 失败，跳过 RTC 同步\n");
		return;
	}

	fd = open("/dev/rtc0", O_RDONLY);
	if (fd < 0) {
		perror("open /dev/rtc0");
		printf("(系统时间已生效，仅 RTC 未同步)\n");
		return;
	}

	rt.tm_year = utc.tm_year;
	rt.tm_mon  = utc.tm_mon;
	rt.tm_mday = utc.tm_mday;
	rt.tm_hour = utc.tm_hour;
	rt.tm_min  = utc.tm_min;
	rt.tm_sec  = utc.tm_sec;

	if (ioctl(fd, RTC_SET_TIME, &rt) < 0)
		perror("RTC_SET_TIME");
	else
		printf("RTC 已同步  : %04d-%02d-%02d %02d:%02d:%02d UTC\n",
		       rt.tm_year + 1900, rt.tm_mon + 1, rt.tm_mday,
		       rt.tm_hour, rt.tm_min, rt.tm_sec);

	close(fd);
}

static void print_tm(const char *tag, const struct tm *tm)
{
	printf("%s: %04d-%02d-%02d %02d:%02d:%02d\n", tag,
	       tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday,
	       tm->tm_hour, tm->tm_min, tm->tm_sec);
}

/* 打印当前系统时间（UTC + 本地）与 RTC 寄存器里的时间 */
static int show_time(void)
{
	struct rtc_time rt;
	struct timeval tv;
	struct tm utc, local;
	const char *tz;
	time_t t;
	int fd;

	gettimeofday(&tv, NULL);
	t = tv.tv_sec;
	gmtime_r(&t, &utc);
	localtime_r(&t, &local);

	tz = getenv("TZ");
	printf("epoch      : %ld\n", (long)t);
	print_tm("UTC        ", &utc);
	printf("本地       : %04d-%02d-%02d %02d:%02d:%02d  (TZ=%s)\n",
	       local.tm_year + 1900, local.tm_mon + 1, local.tm_mday,
	       local.tm_hour, local.tm_min, local.tm_sec,
	       tz ? tz : "未设置");

	fd = open("/dev/rtc0", O_RDONLY);
	if (fd < 0) {
		perror("open /dev/rtc0");
		return 1;
	}
	if (ioctl(fd, RTC_RD_TIME, &rt) < 0) {
		perror("RTC_RD_TIME");
		close(fd);
		return 1;
	}
	printf("RTC(UTC)   : %04d-%02d-%02d %02d:%02d:%02d\n",
	       rt.tm_year + 1900, rt.tm_mon + 1, rt.tm_mday,
	       rt.tm_hour, rt.tm_min, rt.tm_sec);
	close(fd);

	return 0;
}

static int set_epoch(time_t t)
{
	struct timeval tv;
	struct tm utc, local;

	tv.tv_sec = t;
	tv.tv_usec = 0;

	if (settimeofday(&tv, NULL) < 0) {
		perror("settimeofday");
		return 1;
	}

	gmtime_r(&t, &utc);
	localtime_r(&t, &local);
	printf("系统时间已设置: %04d-%02d-%02d %02d:%02d:%02d UTC"
	       " (= 本地 %04d-%02d-%02d %02d:%02d:%02d)\n",
	       utc.tm_year + 1900, utc.tm_mon + 1, utc.tm_mday,
	       utc.tm_hour, utc.tm_min, utc.tm_sec,
	       local.tm_year + 1900, local.tm_mon + 1, local.tm_mday,
	       local.tm_hour, local.tm_min, local.tm_sec);

	sync_rtc(t);
	return 0;
}

static void usage(const char *prog)
{
	fprintf(stderr,
		"用法:\n"
		"  %s --epoch <秒>             用 Unix 时间戳设置并写 RTC\n"
		"  %s --show                   打印 UTC / 本地 / RTC 时间\n"
		"  %s <年> <月> <日> <时> <分> <秒>  按本地时区解释后设置\n",
		prog, prog, prog);
}

int main(int argc, char **argv)
{
	if (argc >= 2 && strcmp(argv[1], "--show") == 0)
		return show_time();

	if (argc == 3 && strcmp(argv[1], "--epoch") == 0) {
		char *end = NULL;
		long long v = strtoll(argv[2], &end, 10);

		if (end == argv[2] || *end != '\0' || v < 0) {
			fprintf(stderr, "无效的时间戳: %s\n", argv[2]);
			return 1;
		}
		return set_epoch((time_t)v);
	}

	if (argc == 7) {
		struct tm tm;
		time_t t;

		memset(&tm, 0, sizeof(tm));
		tm.tm_year = atoi(argv[1]) - 1900;
		tm.tm_mon  = atoi(argv[2]) - 1;
		tm.tm_mday = atoi(argv[3]);
		tm.tm_hour = atoi(argv[4]);
		tm.tm_min  = atoi(argv[5]);
		tm.tm_sec  = atoi(argv[6]);
		tm.tm_isdst = -1;	/* 让 libc 按本地时区判断夏令时 */

		t = mktime(&tm);
		if (t == (time_t)-1) {
			fprintf(stderr, "无效的时间\n");
			return 1;
		}
		return set_epoch(t);
	}

	usage(argv[0]);
	return 1;
}
