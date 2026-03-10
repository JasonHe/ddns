#!/bin/bash
set -euo pipefail

SERVICE_NAME="ddns-go"
INSTALL_PATH="/usr/bin/ddns-go"
BACKUP_PATH="/usr/bin/ddns-go.bak"
TMP_DIR="$(mktemp -d)"
INIT_SYSTEM=""

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log() {
  echo "==> $*"
}

warn() {
  echo "Warning: $*" >&2
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "please run this script as root."
}

detect_pkg_manager() {
  if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"
  elif command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
  else
    fail "unsupported package manager. Supported: apt, dnf, yum, pacman, zypper, apk"
  fi

  log "Detected package manager: ${PKG_MANAGER}"
}

install_dependencies() {
  log "Installing required packages..."

  case "$PKG_MANAGER" in
    apt)
      apt update
      apt install -y curl wget tar jq binutils
      ;;
    dnf)
      dnf install -y curl wget tar jq binutils
      ;;
    yum)
      yum install -y curl wget tar jq binutils
      ;;
    pacman)
      pacman -Sy --noconfirm curl wget tar jq binutils
      ;;
    zypper)
      zypper --non-interactive install curl wget tar jq binutils
      ;;
    apk)
      apk update
      apk add curl wget tar jq binutils
      ;;
    *)
      fail "unknown package manager: ${PKG_MANAGER}"
      ;;
  esac
}

detect_init_system() {
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    INIT_SYSTEM="systemd"
  elif command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
    INIT_SYSTEM="openrc"
  else
    INIT_SYSTEM="none"
  fi

  log "Detected init system: ${INIT_SYSTEM}"
}

detect_mips_float() {
  local prefix="$1"

  if command -v readelf >/dev/null 2>&1; then
    if readelf -A /bin/sh 2>/dev/null | grep -Eqi 'hard float|hardfloat'; then
      echo "${prefix}_hardfloat"
      return
    fi
    if readelf -A /bin/sh 2>/dev/null | grep -Eqi 'soft float|softfloat'; then
      echo "${prefix}_softfloat"
      return
    fi
  fi

  echo "${prefix}_softfloat"
}

detect_arch() {
  local machine
  machine="$(uname -m)"

  case "$machine" in
    x86_64|amd64)
      DDNS_ARCH="linux_x86_64"
      ;;
    i386|i486|i586|i686)
      DDNS_ARCH="linux_i386"
      ;;
    aarch64|arm64)
      DDNS_ARCH="linux_arm64"
      ;;
    armv5*|arm5*)
      DDNS_ARCH="linux_armv5"
      ;;
    armv6*|arm6*)
      DDNS_ARCH="linux_armv6"
      ;;
    armv7*|armv7l|armhf|arm)
      DDNS_ARCH="linux_armv7"
      ;;
    mips64el)
      DDNS_ARCH="$(detect_mips_float "linux_mips64le")"
      ;;
    mips64)
      DDNS_ARCH="$(detect_mips_float "linux_mips64")"
      ;;
    mipsel)
      DDNS_ARCH="$(detect_mips_float "linux_mipsle")"
      ;;
    mips)
      DDNS_ARCH="$(detect_mips_float "linux_mips")"
      ;;
    riscv64)
      DDNS_ARCH="linux_riscv64"
      ;;
    *)
      fail "unsupported architecture: ${machine}"
      ;;
  esac

  log "Detected architecture: ${machine} -> ${DDNS_ARCH}"
}

get_latest_download_url() {
  local api_url json url

  api_url="https://api.github.com/repos/jeessy2/ddns-go/releases/latest"

  log "Fetching latest release metadata..."
  json="$(curl -fsSL "$api_url")" || fail "failed to fetch GitHub release metadata"

  url="$(echo "$json" | jq -r --arg arch "$DDNS_ARCH" '
    .assets[]
    | select(.name | test($arch + "\\.tar\\.gz$"))
    | .browser_download_url
  ' | head -n 1)"

  [[ -n "$url" && "$url" != "null" ]] || fail "failed to find release asset for ${DDNS_ARCH}"

  DOWNLOAD_URL="$url"
  log "Matched download URL: ${DOWNLOAD_URL}"
}

service_exists() {
  case "$INIT_SYSTEM" in
    systemd)
      systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}\.service"
      ;;
    openrc)
      [[ -f "/etc/init.d/${SERVICE_NAME}" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

stop_service_if_exists() {
  case "$INIT_SYSTEM" in
    systemd)
      if service_exists; then
        log "Stopping existing service with systemd..."
        systemctl stop "$SERVICE_NAME" || true
      else
        log "Service ${SERVICE_NAME}.service not found, skip stopping."
      fi
      ;;
    openrc)
      if service_exists; then
        log "Stopping existing service with OpenRC..."
        rc-service "$SERVICE_NAME" stop || true
      else
        log "Service /etc/init.d/${SERVICE_NAME} not found, skip stopping."
      fi
      ;;
    none)
      log "No supported init system found, skip stopping service."
      ;;
  esac
}

download_and_extract() {
  log "Downloading package..."
  cd "$TMP_DIR"
  wget -O ddns-go.tar.gz "$DOWNLOAD_URL" || fail "download failed"

  log "Extracting package..."
  tar -xzf ddns-go.tar.gz || fail "extract failed"

  [[ -f "$TMP_DIR/ddns-go" ]] || fail "ddns-go binary not found after extraction"
  chmod +x "$TMP_DIR/ddns-go"
}

backup_existing_binary() {
  if [[ -f "$INSTALL_PATH" ]]; then
    log "Backing up existing binary to ${BACKUP_PATH}..."
    cp -f "$INSTALL_PATH" "$BACKUP_PATH"
  fi
}

install_new_binary() {
  log "Installing new binary..."
  cp -f "$TMP_DIR/ddns-go" "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
}

install_or_update_service() {
  case "$INIT_SYSTEM" in
    systemd|openrc)
      log "Installing/updating service..."
      "$INSTALL_PATH" -s install || fail "service install failed"
      ;;
    none)
      warn "No supported init system detected. Binary upgraded, but service was not installed."
      ;;
  esac
}

enable_service() {
  case "$INIT_SYSTEM" in
    systemd)
      systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
      ;;
    openrc)
      rc-update add "$SERVICE_NAME" default >/dev/null 2>&1 || true
      ;;
    none)
      :
      ;;
  esac
}

restart_service() {
  case "$INIT_SYSTEM" in
    systemd)
      systemctl restart "$SERVICE_NAME"
      ;;
    openrc)
      rc-service "$SERVICE_NAME" restart
      ;;
    none)
      return 1
      ;;
  esac
}

is_service_active() {
  case "$INIT_SYSTEM" in
    systemd)
      systemctl is-active --quiet "$SERVICE_NAME"
      ;;
    openrc)
      rc-service "$SERVICE_NAME" status >/dev/null 2>&1
      ;;
    none)
      return 1
      ;;
  esac
}

show_service_status() {
  case "$INIT_SYSTEM" in
    systemd)
      systemctl --no-pager --full status "$SERVICE_NAME" || true
      ;;
    openrc)
      rc-service "$SERVICE_NAME" status || true
      ;;
    none)
      :
      ;;
  esac
}

start_and_verify_service() {
  case "$INIT_SYSTEM" in
    systemd|openrc)
      log "Enabling service..."
      enable_service

      log "Restarting service..."
      restart_service || return 1

      log "Verifying service status..."
      is_service_active
      ;;
    none)
      warn "No supported init system detected. Please start ddns-go manually."
      return 0
      ;;
  esac
}

rollback() {
  if [[ -f "$BACKUP_PATH" ]]; then
    log "Rolling back to previous binary..."
    cp -f "$BACKUP_PATH" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    case "$INIT_SYSTEM" in
      systemd)
        systemctl restart "$SERVICE_NAME" || true
        ;;
      openrc)
        rc-service "$SERVICE_NAME" restart || true
        ;;
      none)
        :
        ;;
    esac
  else
    log "No backup binary found, cannot roll back."
  fi
}

main() {
  require_root
  detect_pkg_manager
  install_dependencies
  detect_init_system
  detect_arch
  get_latest_download_url
  stop_service_if_exists
  download_and_extract
  backup_existing_binary
  install_new_binary
  install_or_update_service

  if ! start_and_verify_service; then
    echo "Error: new version failed to start." >&2
    rollback
    fail "upgrade failed and rollback attempted"
  fi

  log "Upgrade completed successfully."
  show_service_status
}

main "$@"
