cmd_lib/div64.o := arm-linux-gnueabihf-gcc -Wp,-MD,lib/.div64.o.d  -nostdinc -isystem /usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/bin/../lib/gcc/arm-linux-gnueabihf/4.9.4/include -Iinclude  -I/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include  -I/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/arch/arm/include -include /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/kconfig.h  -I/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/lib -Ilib -D__KERNEL__ -D__UBOOT__ -Wall -Wstrict-prototypes -Wno-format-security -fno-builtin -ffreestanding -Os -fno-stack-protector -fno-delete-null-pointer-checks -g -fstack-usage -Wno-format-nonliteral -Werror=date-time -D__ARM__ -marm -mno-thumb-interwork -mabi=aapcs-linux -mword-relocations -fno-pic -mno-unaligned-access -ffunction-sections -fdata-sections -fno-common -ffixed-r9 -msoft-float -pipe -march=armv7-a    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(div64)"  -D"KBUILD_MODNAME=KBUILD_STR(div64)" -c -o lib/div64.o /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/lib/div64.c

source_lib/div64.o := /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/lib/div64.c

deps_lib/div64.o := \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/div64.h \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/types.h \
    $(wildcard include/config/uid16.h) \
    $(wildcard include/config/use/stdint.h) \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/posix_types.h \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/stddef.h \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/arch/arm/include/asm/posix_types.h \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/arch/arm/include/asm/types.h \
    $(wildcard include/config/arm64.h) \
    $(wildcard include/config/phys/64bit.h) \
  /usr/local/arm/gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf/lib/gcc/arm-linux-gnueabihf/4.9.4/include/stdbool.h \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/compiler.h \
    $(wildcard include/config/sparse/rcu/pointer.h) \
    $(wildcard include/config/trace/branch/profiling.h) \
    $(wildcard include/config/profile/all/branches.h) \
    $(wildcard include/config/kasan.h) \
    $(wildcard include/config/enable/must/check.h) \
    $(wildcard include/config/enable/warn/deprecated.h) \
    $(wildcard include/config/kprobes.h) \
  /home/pointer/imx6ull/projects/imx6ull-nxp-bsp/sources/uboot-imx/include/linux/compiler-gcc.h \
    $(wildcard include/config/arch/supports/optimized/inlining.h) \
    $(wildcard include/config/optimize/inlining.h) \
    $(wildcard include/config/gcov/kernel.h) \
    $(wildcard include/config/arch/use/builtin/bswap.h) \

lib/div64.o: $(deps_lib/div64.o)

$(deps_lib/div64.o):
