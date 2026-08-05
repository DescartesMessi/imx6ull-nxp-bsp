# M0-B: NXP official baseline build

## Status

Completed.

## Source baseline

- NXP BSP: `rel_imx_4.1.15_2.1.0_ga`
- U-Boot: `2016.03`
- Linux: `4.1.15`
- Toolchain: Linaro GCC `4.9.4`
- Architecture: ARMv7

## U-Boot

- Defconfig: `mx6ull_14x14_evk_emmc_defconfig`
- Output:
  - `u-boot`
  - `u-boot.bin`
  - `u-boot.imx`
  - `System.map`
- Source worktree remained clean.

## Linux

- Defconfig: `imx_v7_defconfig`
- Device tree: `imx6ull-14x14-evk-emmc.dtb`
- Output:
  - `zImage`
  - `vmlinux`
  - `System.map`
  - `imx6ull-14x14-evk-emmc.dtb`
  - 72 kernel modules
- Kernel release: `4.1.15`
- Build identity: `bsp-builder@imx6ull-nxp-bsp`
- Source worktree remained clean.

## Checksums

Build metadata and SHA-256 checksums are stored under:

`artifacts/m0-official-build/`

## Scope

This milestone validates an unmodified NXP EVK software baseline. It does not
yet contain JJL/ALIENTEK-specific DDR, eMMC, Ethernet, LCD, audio or peripheral
adaptation.

## Next milestone

M0-C: boot the newly built NXP Linux kernel and EVK device tree using the
already verified development-board U-Boot, while continuing to use the known
working eMMC root filesystem.
