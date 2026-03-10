# ddns-go Install/Upgrade Script

[中文说明 / Chinese Version](README_CN.md)

## Quick Install

```bash
wget -qO- https://github.com/JasonHe/ddns/raw/main/ddns.sh | bash
```

After installation, open `http://IP:9876` in your browser to complete the configuration.

A robust cross-distribution upgrade script for [ddns-go](https://github.com/jeessy2/ddns-go).

This project provides an upgrade script that:

- fetches the latest `ddns-go` release from GitHub
- parses release metadata with `jq`
- detects supported Linux CPU architectures automatically
- supports multiple Linux distributions and package managers
- supports both `systemd` and `OpenRC`
- backs up the existing binary before replacement
- attempts rollback automatically if the upgraded service fails to start

## Features

- Safe upgrade flow
  - does **not** delete the old binary before the new one is downloaded and extracted
  - creates a backup before replacing the executable
  - attempts rollback on startup failure
- Release metadata parsing with `jq`
- Broad Linux distribution support
- Broad CPU architecture support
- Temporary workspace cleanup with `mktemp`
- Service management support for:
  - `systemd`
  - `OpenRC`

## Supported package managers

- `apt`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `apk`

## Supported architectures

This script is designed to match all currently published Linux builds of `ddns-go`:

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

## Supported init systems

- `systemd`
- `OpenRC`

If no supported init system is detected, the script can still upgrade the binary, but service installation and service restart may need to be handled manually.

## Requirements

- Linux
- root privileges
- internet access to GitHub
- one of the supported package managers listed above

## Dependencies

The script installs the following tools automatically when needed:

- `curl`
- `wget`
- `tar`
- `jq`
- `binutils`

## Usage

### 1. Save the script

Save your upgrade script as, for example:

```bash
upgrade-ddns-go.sh
```

### 2. Make it executable

```bash
chmod +x upgrade-ddns-go.sh
```

### 3. Run it as root

```bash
sudo ./upgrade-ddns-go.sh
```

## What the script does

1. Detects the package manager
2. Installs required dependencies
3. Detects the init system
4. Detects CPU architecture
5. Fetches the latest `ddns-go` release metadata from GitHub
6. Selects the correct release asset
7. Stops the existing service if present
8. Downloads and extracts the new package
9. Backs up the existing binary
10. Replaces the installed binary
11. Installs or updates the service
12. Restarts the service
13. Verifies service health
14. Rolls back automatically if startup fails

## Notes

### About MIPS hardfloat / softfloat detection

For MIPS and MIPS64 targets, the script tries to distinguish between `hardfloat` and `softfloat` by inspecting ELF attributes via `readelf`.

This is a practical approach, but not guaranteed to be perfect on every custom distribution or toolchain. If you are deploying on uncommon MIPS devices, validate the detected architecture before production use.

### About OpenRC support

The script supports OpenRC service control logic. However, whether `ddns-go -s install` can install a native OpenRC service depends on `ddns-go` itself.

If `ddns-go` does not generate an OpenRC service script on your platform, you may need to create `/etc/init.d/ddns-go` manually.

## Example project structure

```text
.
├── upgrade-ddns-go.sh
├── README.md
└── README_CN.md
```

## Disclaimer

Use at your own risk. Although the script includes backup and rollback logic, you should still test it in your own environment before using it on production systems.

## License

You may choose any license appropriate for your project. If you do not yet have one, consider adding an MIT License file.

## Related project

- `ddns-go`: https://github.com/jeessy2/ddns-go
