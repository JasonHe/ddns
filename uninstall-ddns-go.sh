#!/bin/bash
set -euo pipefail

SERVICE_NAME="ddns-go"
INSTALL_PATH="/usr/bin/ddns-go"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/ddns-go.service"
OPENRC_SERVICE_FILE="/etc/init.d/ddns-go"

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

stop_and_disable_service() {
  case "${INIT_SYSTEM}" in
    systemd)
      if systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}\\.service"; then
        log "Stopping ${SERVICE_NAME} service..."
        systemctl stop "${SERVICE_NAME}" || true
        log "Disabling ${SERVICE_NAME} service..."
        systemctl disable "${SERVICE_NAME}" || true
      else
        log "Systemd service not found, skip."
      fi
      ;;
    openrc)
      if [[ -f "${OPENRC_SERVICE_FILE}" ]]; then
        log "Stopping ${SERVICE_NAME} service..."
        rc-service "${SERVICE_NAME}" stop || true
        log "Removing ${SERVICE_NAME} from default runlevel..."
        rc-update del "${SERVICE_NAME}" default || true
      else
        log "OpenRC service not found, skip."
      fi
      ;;
    none)
      warn "No supported init system detected. Will only remove files."
      ;;
  esac
}

remove_service_files() {
  if [[ -f "${SYSTEMD_SERVICE_FILE}" ]]; then
    log "Removing systemd service file..."
    rm -f "${SYSTEMD_SERVICE_FILE}"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload || true
    fi
  fi

  if [[ -f "${OPENRC_SERVICE_FILE}" ]]; then
    log "Removing OpenRC service file..."
    rm -f "${OPENRC_SERVICE_FILE}"
  fi
}

remove_binary() {
  if [[ -f "${INSTALL_PATH}" ]]; then
    log "Removing binary..."
    rm -f "${INSTALL_PATH}"
  else
    log "Binary not found, skip."
  fi
}

show_possible_residuals() {
  echo
  log "Uninstall completed."
  echo "Possible remaining ddns-go related files can be searched with:"
  echo "find / -name '*ddns-go*' 2>/dev/null"
  echo
  echo "If you also want to delete configuration or data files, check the locations returned by the command above."
}

main() {
  require_root
  detect_init_system
  stop_and_disable_service
  remove_service_files
  remove_binary
  show_possible_residuals
}

main "$@"
