# 项目架构

## 基线层

- NXP `uboot-imx`：官方 tag，不在顶层仓库中提交完整源码。
- NXP `linux-imx`：官方 tag，不在顶层仓库中提交完整源码。
- `manifest/locked-revisions.local`：本地记录 tag 对应 commit。

## 板级层

- U-Boot 开发分支：`board/imx6ull-jjl`
- Linux 开发分支：`board/imx6ull-jjl`
- 所有板级修改导出到 `patches/uboot` 与 `patches/linux`。

## 编排层

顶层 GitHub 仓库保存：

- 构建脚本
- 配置文件
- patch series
- RootFS overlay
- 测试记录
- 文档和版本清单

不保存：

- NXP 完整源码
- 编译中间文件
- zImage/DTB/U-Boot 大二进制
- 解压后的 RootFS
- 密钥与凭据
