/*
 * v4l2_enum.c - 枚举 V4L2 摄像头真正支持的格式、分辨率与帧率
 *
 * 用途：核对"应用请求的分辨率"和"实际协商到的分辨率"是否一致。
 * 本板实测：应用请求 320x240@15，但摄像头返回 640x480 YUYV，
 * 每帧要转换的像素量是预期的 4 倍，这是预览 CPU 偏高的直接原因。
 *
 * 用法：v4l2_enum <设备节点>          例：v4l2_enum /dev/video1
 *
 * 交叉编译：
 *   arm-linux-gnueabihf-gcc -static -O2 -o v4l2_enum v4l2_enum.c
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <linux/videodev2.h>
#include <sys/ioctl.h>

static const char *type_name(unsigned int type)
{
	switch (type) {
	case V4L2_BUF_TYPE_VIDEO_CAPTURE:
		return "VIDEO_CAPTURE";
	case V4L2_BUF_TYPE_VIDEO_OUTPUT:
		return "VIDEO_OUTPUT";
	case V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE:
		return "CAPTURE_MPLANE";
	default:
		return "OTHER";
	}
}

int main(int argc, char **argv)
{
	struct v4l2_capability cap;
	struct v4l2_fmtdesc fmt;
	int fd;

	if (argc != 2) {
		fprintf(stderr, "用法: %s <设备节点>\n", argv[0]);
		return 1;
	}

	fd = open(argv[1], O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "打开 %s 失败: %s\n", argv[1], strerror(errno));
		return 1;
	}

	memset(&cap, 0, sizeof(cap));
	if (ioctl(fd, VIDIOC_QUERYCAP, &cap) < 0) {
		fprintf(stderr, "VIDIOC_QUERYCAP 失败: %s\n", strerror(errno));
		close(fd);
		return 1;
	}

	printf("设备      : %s\n", argv[1]);
	printf("驱动      : %s\n", cap.driver);
	printf("名称      : %s\n", cap.card);
	printf("总线      : %s\n", cap.bus_info);
	printf("能力      : 0x%08x%s%s\n", cap.capabilities,
	       (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE) ? " CAPTURE" : "",
	       (cap.capabilities & V4L2_CAP_STREAMING) ? " STREAMING" : "");
	printf("\n");

	memset(&fmt, 0, sizeof(fmt));
	fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;

	for (fmt.index = 0; ; fmt.index++) {
		if (ioctl(fd, VIDIOC_ENUM_FMT, &fmt) < 0)
			break;

		printf("格式 %u: %c%c%c%c  %s\n",
		       fmt.index,
		       (fmt.pixelformat) & 0xff,
		       (fmt.pixelformat >> 8) & 0xff,
		       (fmt.pixelformat >> 16) & 0xff,
		       (fmt.pixelformat >> 24) & 0xff,
		       fmt.description);

		{
			struct v4l2_frmsizeenum size;

			memset(&size, 0, sizeof(size));
			size.pixel_format = fmt.pixelformat;

			for (size.index = 0; ; size.index++) {
				if (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &size) < 0)
					break;

				if (size.type == V4L2_FRMSIZE_TYPE_DISCRETE) {
					struct v4l2_frmivalenum interval;

					printf("    分辨率 %ux%u ",
					       size.discrete.width,
					       size.discrete.height);

					memset(&interval, 0, sizeof(interval));
					interval.pixel_format = fmt.pixelformat;
					interval.width = size.discrete.width;
					interval.height = size.discrete.height;

					if (interval.width == 0 || interval.height == 0) {
						printf("\n");
						continue;
					}

					for (interval.index = 0; ; interval.index++) {
						if (ioctl(fd,
							  VIDIOC_ENUM_FRAMEINTERVALS,
							  &interval) < 0)
							break;

						if (interval.type ==
						    V4L2_FRMIVAL_TYPE_DISCRETE) {
							const unsigned int num =
								interval.discrete.numerator;
							const unsigned int den =
								interval.discrete.denominator;

							printf("%u/%ufps ",
							       num ? den / num : 0,
							       1);
						}
					}
					printf("\n");
				} else {
					printf("    连续/步进分辨率范围 %ux%u - %ux%u\n",
					       size.stepwise.min_width,
					       size.stepwise.min_height,
					       size.stepwise.max_width,
					       size.stepwise.max_height);
				}
			}
		}
	}

	close(fd);
	return 0;
}
