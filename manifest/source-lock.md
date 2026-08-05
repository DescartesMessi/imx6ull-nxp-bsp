# NXP BSP source baseline

## BSP release

- Release: `rel_imx_4.1.15_2.1.0_ga`
- Target SoC: NXP i.MX6ULL
- Target board: ALIENTEK/JJL i.MX6ULL eMMC board
- Architecture: ARMv7
- Toolchain: Linaro GCC 4.9.4
- Cross compiler prefix: `arm-linux-gnueabihf-`

## U-Boot

- Official repository: `https://github.com/nxp-imx/uboot-imx.git`
- Release reference: `rel_imx_4.1.15_2.1.0_ga`
- Source archive: `uboot-imx-rel_imx_4.1.15_2.1.0_ga.tar.bz2`
- SHA-256: `bd8fe4cc363f2ed9b461ff5deef1c4cd0b802c4cf1e452cedb2105dd6d92d754`
- Imported version: U-Boot 2016.03
- Local baseline tag: `nxp-baseline`

## Linux

- Official repository: `https://github.com/nxp-imx/linux-imx.git`
- Release reference: `rel_imx_4.1.15_2.1.0_ga`
- Source archive: `linux-imx-rel_imx_4.1.15_2.1.0_ga.tar.bz2`
- SHA-256: `71cc67d881430f8d2b0169bff172eef6e67416f4762c7d7a99e894bf2d847050`
- Imported version: Linux 4.1.15
- Local baseline tag: `nxp-baseline`

## Source-management policy

The complete NXP source trees are kept locally under `sources/` and are not
committed to the top-level project repository.

Board-specific U-Boot and Linux changes are exported as patch series into:

- `patches/uboot/`
- `patches/linux/`

Local snapshot commit IDs are not treated as original NXP Git commit IDs.
The release names and SHA-256 archive checksums are the reproducible source
identifiers.
