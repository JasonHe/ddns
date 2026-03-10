# ddns-go 一键安装/升级脚本

[English Version / 英文说明](README.md)

## 一键安装

```bash
wget -qO- https://github.com/JasonHe/ddns/raw/main/ddns.sh | bash
```

安装完成后，请在浏览器中打开 `http://IP:9876` 进行配置。

这是一个面向 [ddns-go](https://github.com/jeessy2/ddns-go) 的增强型跨发行版升级脚本项目。

该项目提供的升级脚本具备以下能力：

- 从 GitHub 自动获取 `ddns-go` 最新版本
- 使用 `jq` 解析 release 元数据
- 自动识别支持的 Linux CPU 架构
- 支持多种 Linux 发行版及包管理器
- 同时支持 `systemd` 和 `OpenRC`
- 替换前自动备份旧版本二进制
- 新版本启动失败时自动尝试回滚

## 功能特性

- 更安全的升级流程
  - 不会在新版本下载完成前删除旧版本
  - 替换前自动备份旧二进制
  - 新版本启动失败时自动尝试回滚
- 使用 `jq` 解析 GitHub API
- 支持多种 Linux 发行版
- 支持多种 CPU 架构
- 使用 `mktemp` 创建临时目录并自动清理
- 支持以下服务管理器：
  - `systemd`
  - `OpenRC`

## 支持的包管理器

- `apt`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `apk`

## 支持的架构

本脚本按照 `ddns-go` 当前发布的全部 Linux 构建进行匹配：

- `linux_arm64`
- `linux_armv5`
- `linux_armv6`
- `linux_armv7`
- `linux_i386`
- `linux_mips64le_hardfloat`
- `linux_mips64le_softfloat`
- `linux_mips64_hardfloat`
- `linux_mips64_softfloat`
- `linux_mipsle_hardfloat`
- `linux_mipsle_softfloat`
- `linux_mips_hardfloat`
- `linux_mips_softfloat`
- `linux_riscv64`
- `linux_x86_64`

## 支持的初始化/服务管理系统

- `systemd`
- `OpenRC`

如果系统未检测到受支持的 init 系统，脚本仍可完成二进制升级，但服务安装和服务重启可能需要手工处理。

## 运行要求

- Linux 系统
- root 权限
- 可访问 GitHub 的网络环境
- 至少具备一种受支持的包管理器

## 依赖项

脚本会在需要时自动安装以下工具：

- `curl`
- `wget`
- `tar`
- `jq`
- `binutils`

## 使用方法

### 1. 保存脚本

例如保存为：

```bash
upgrade-ddns-go.sh
```

### 2. 添加执行权限

```bash
chmod +x upgrade-ddns-go.sh
```

### 3. 以 root 身份运行

```bash
sudo ./upgrade-ddns-go.sh
```

## 脚本执行流程

1. 检测包管理器
2. 安装所需依赖
3. 检测 init 系统
4. 检测 CPU 架构
5. 从 GitHub 获取最新 `ddns-go` release 元数据
6. 选择正确的发布包
7. 如已有服务则先停止
8. 下载并解压新版本
9. 备份旧二进制
10. 替换已安装的程序文件
11. 安装或更新服务
12. 重启服务
13. 验证服务状态
14. 若启动失败则自动回滚

## 注意事项

### 关于 MIPS hardfloat / softfloat 识别

对于 MIPS 和 MIPS64 平台，脚本会尝试通过 `readelf` 检查 ELF 属性，以区分 `hardfloat` 与 `softfloat`。

这是一种比较实用的自动识别方式，但在某些特殊发行版、裁剪系统或定制工具链环境中，不能保证 100% 准确。如果你的目标设备属于较少见的 MIPS 平台，建议在正式环境使用前先验证识别结果。

### 关于 OpenRC 支持

脚本本身已经支持 OpenRC 的服务控制逻辑，但 `ddns-go -s install` 是否能够在你的系统上自动生成原生 OpenRC 服务脚本，仍取决于 `ddns-go` 本身的实现。

如果 `ddns-go` 在你的平台上不会自动生成 OpenRC 服务文件，你可能仍需要手工创建 `/etc/init.d/ddns-go`。

## 示例项目结构

```text
.
├── upgrade-ddns-go.sh
├── README.md
└── README_CN.md
```

## 免责声明

请自行评估风险后使用。虽然脚本已经包含备份与回滚逻辑，但在生产环境使用前，仍建议先在测试环境完成验证。

## 许可证

你可以根据项目需要自行选择许可证。如果暂时还没有，通常可以考虑添加 MIT License。

## 相关项目

- `ddns-go`: https://github.com/jeessy2/ddns-go
