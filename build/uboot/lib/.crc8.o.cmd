cmd_lib/crc8.o := arm-linux-gnueabihf-gcc -Wp,-MD,lib/.crc8.o.d  -nostdinc -isystem /usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin/../lib/gcc/arm-linux-gnueabihf/4.9.4/include -Iinclude  -I/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include  -I/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/arch/arm/include -include /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/kconfig.h  -I/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/lib -Ilib -D__KERNEL__ -D__UBOOT__ -Wall -Wstrict-prototypes -Wno-format-security -fno-builtin -ffreestanding -Os -fno-stack-protector -fno-delete-null-pointer-checks -g -fstack-usage -Wno-format-nonliteral -Werror=date-time -D__ARM__ -marm -mno-thumb-interwork -mabi=aapcs-linux -mword-relocations -fno-pic -mno-unaligned-access -ffunction-sections -fdata-sections -fno-common -ffixed-r9 -msoft-float -pipe -march=armv7-a    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(crc8)"  -D"KBUILD_MODNAME=KBUILD_STR(crc8)" -c -o lib/crc8.o /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/lib/crc8.c

source_lib/crc8.o := /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/lib/crc8.c

deps_lib/crc8.o := \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/crc8.h \

lib/crc8.o: $(deps_lib/crc8.o)

$(deps_lib/crc8.o):
