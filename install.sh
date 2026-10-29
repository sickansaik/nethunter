#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Main Installer
###############################################################################

###############################################################################
# Termux architecture / process-personality bootstrap
#
# Android may leave the calling shell in PER_LINUX32. In that state uname -m
# reports armv8l even though Termux itself is native aarch64. proot-distro uses
# the process architecture signal and may then incorrectly require QEMU for an
# existing native aarch64 Ubuntu container.
#
# Termux dpkg is the authoritative host-package architecture signal here.
# Normalize the process personality before any proot-distro interaction.
###############################################################################

NHT_TERMUX_ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
NHT_UNAME_ARCH="$(uname -m 2>/dev/null || true)"
NHT_PERSONALITY="$(setarch --show 2>/dev/null || true)"

if [[ "$NHT_TERMUX_ARCH" == "aarch64" ]] &&
   [[ "$NHT_UNAME_ARCH" != "aarch64" || "$NHT_PERSONALITY" == "PER_LINUX32" ]]
then
    if [[ "${NHT_ARCH_REEXEC:-0}" == "1" ]]; then
        echo "[!] Architecture normalization failed." >&2
        echo "[!] dpkg=$NHT_TERMUX_ARCH uname=$NHT_UNAME_ARCH personality=$NHT_PERSONALITY" >&2
        exit 1
    fi

    if ! command -v setarch >/dev/null 2>&1; then
        echo "[!] Native aarch64 Termux detected, but setarch is unavailable." >&2
        echo "[!] Cannot safely normalize a Linux32 process personality." >&2
        exit 1
    fi

    export NHT_ARCH_REEXEC=1

    exec setarch aarch64         /data/data/com.termux/files/usr/bin/bash         "${BASH_SOURCE[0]}" "$@"
fi

unset NHT_ARCH_REEXEC 2>/dev/null || true

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Versionsinformation
###############################################################################

source "$SCRIPT_DIR/config/version.conf"

###############################################################################
# Bibliotek
###############################################################################

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/checks.sh"
source "$SCRIPT_DIR/lib/functions.sh"

###############################################################################
# Installer CLI
###############################################################################

install_usage() {
    cat <<EOF
NetHunter Toolkit Installer

Usage:
  ./install.sh
  ./install.sh --help

Commands:
  --help, -h
      Show this help and exit without modifying the system.

Planned:
  --preflight
      Validate the Termux/Android environment before installation.

  --qualify
      Validate an installed NetHunter Toolkit environment.

Default:
  Running ./install.sh without arguments performs the normal installation.
EOF
}

case "${1:-}" in
    "")
        ;;
    --help|-h)
        install_usage
        exit 0
        ;;
    *)
        echo "[✗] Unknown installer option: $1" >&2
        echo >&2
        install_usage >&2
        exit 2
        ;;
esac

if (( $# > 1 )); then
    echo "[✗] Too many installer arguments." >&2
    echo >&2
    install_usage >&2
    exit 2
fi

###############################################################################
# Start
###############################################################################

START_TIME=$(date +%s)

title

log_info "$TOOLKIT_NAME v$TOOLKIT_VERSION"
log_info "Codename: $TOOLKIT_CODENAME"
log_info "Status: $TOOLKIT_STATUS"

echo

###############################################################################
# Systemkontroller
###############################################################################

log_info "Kontrollerar system..."

check_internet
check_cpu
check_android
check_storage
check_ubuntu

echo

###############################################################################
# Moduler
###############################################################################

MODULES=(
    "01-termux.sh"
    "02-ubuntu.sh"
    "03-x11.sh"
    "04-xfce.sh"
    "05-security.sh"
    "06-devtools.sh"
    "07-performance.sh"
    "08-desktop-shortcuts.sh"
)

if ! run_modules "${MODULES[@]}"; then
    log_warn "Module Engine rapporterade ett eller flera modulfel."
fi

###############################################################################
# Slutrapport
###############################################################################

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo
echo "============================================"
echo "        $TOOLKIT_NAME"
echo "============================================"
echo
echo "Version : $TOOLKIT_VERSION"
echo "Codename: $TOOLKIT_CODENAME"
echo "Status  : $TOOLKIT_STATUS"
echo "Tid     : ${ELAPSED} sekunder"
echo
echo "Logg:"
echo "$SCRIPT_DIR/logs/install.log"
echo "============================================"

###############################################################################
# Central System Status
###############################################################################

SYSTEM_STATUS_RC=0

if ! print_system_status; then
    SYSTEM_STATUS_RC=1
fi

###############################################################################
# Final install result
###############################################################################

if (( SYSTEM_STATUS_RC == 0 )); then
    log_ok "Installationen slutförd utan fel."
    exit 0
fi

log_error "Installationen avslutades med fel."
exit 1
