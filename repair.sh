#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Repair / Diagnostics
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/lib/runtime.sh"

PASS=0
WARNINGS=0
FAILS=0

check_ok() {
    echo -e "${GREEN}[✓]${RESET} $1"
    ((PASS+=1))
}

check_warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
    ((WARNINGS+=1))
}

check_fail() {
    echo -e "${RED}[✗]${RESET} $1"
    ((FAILS+=1))
}

echo
echo "============================================"
echo "        NetHunter Toolkit Repair"
echo "============================================"
echo
info "Version: $TOOLKIT_VERSION"
echo

###############################################################################
# 1. Termux:X11 runtime
###############################################################################

echo "============================================"
echo "X11 RUNTIME"
echo "============================================"

if command -v termux-x11 >/dev/null 2>&1; then
    check_ok "Termux:X11 installerad"
else
    check_fail "Termux:X11 saknas"
fi

if runtime_x11_running; then
    check_ok "Termux:X11 runtime aktiv"
else
    check_warn "Termux:X11 runtime är inte nåbar"
fi

check_ok "DISPLAY=$RUNTIME_X11_DISPLAY"

###############################################################################
# 2. Ubuntu
###############################################################################

echo
echo "============================================"
echo "UBUNTU"
echo "============================================"

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1; then
    check_ok "Ubuntu"
else
    check_fail "Ubuntu kan inte startas"
fi

###############################################################################
# 3. XFCE / DBus
###############################################################################

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
    'command -v startxfce4 >/dev/null 2>&1'
then
    check_ok "XFCE"
else
    check_fail "XFCE saknas"
fi

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
    'command -v dbus-launch >/dev/null 2>&1'
then
    check_ok "DBus"
else
    check_fail "DBus saknas"
fi

###############################################################################
# 4. X11 connectivity
###############################################################################

echo
echo "============================================"
echo "X11 CONNECTIVITY"
echo "============================================"

if runtime_x11_test; then
    check_ok "Termux → X11"
else
    check_warn "Termux → X11 kunde inte verifieras"
fi

if runtime_ubuntu_x11_test; then
    check_ok "Ubuntu → Termux:X11"
else
    check_warn "Ubuntu → Termux:X11 kunde inte verifieras"
fi

###############################################################################
# SUMMARY
###############################################################################

echo
echo "============================================"
echo "        REPAIR RESULT"
echo "============================================"
echo
echo "Godkända : $PASS"
echo "Varningar: $WARNINGS"
echo "Fel      : $FAILS"

echo

if (( FAILS > 0 )); then
    log_error "REPAIR FAILED"
    exit 2
elif (( WARNINGS > 0 )); then
    log_warn "REPAIR COMPLETED WITH WARNINGS"
    exit 1
else
    log_ok "REPAIR GREEN"
    exit 0
fi
