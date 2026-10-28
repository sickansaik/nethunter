#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Doctor / Deep Diagnostics
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/lib/pulse.sh"
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

###############################################################################
# Header
###############################################################################

echo
echo "============================================"
echo "        NetHunter Toolkit Doctor"
echo "============================================"
echo
echo "Version : $TOOLKIT_VERSION"
echo "Mode    : Read-only deep diagnostics"
echo

###############################################################################
# CORE
###############################################################################

echo "============================================"
echo "CORE"
echo "============================================"

if command -v proot-distro >/dev/null 2>&1; then
    check_ok "proot-distro"
else
    check_fail "proot-distro"
fi

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1; then
    check_ok "Ubuntu"
else
    check_fail "Ubuntu"
fi

if command -v termux-x11 >/dev/null 2>&1; then
    check_ok "Termux:X11"
else
    check_fail "Termux:X11"
fi

if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    check_ok "PulseAudio"
else
    check_warn "PulseAudio"
fi

###############################################################################
# X11
###############################################################################

echo
echo "============================================"
echo "X11"
echo "============================================"

DISPLAY_VALUE="$RUNTIME_X11_DISPLAY"

if runtime_x11_running; then
    check_ok "X11 socket"
else
    check_fail "X11 socket"
fi

echo "    DISPLAY=$DISPLAY_VALUE"

if runtime_x11_test; then
    check_ok "Termux → X11"
else
    check_fail "Termux → X11"
fi

if runtime_ubuntu_x11_test; then
    check_ok "Ubuntu → X11"
else
    check_fail "Ubuntu → X11"
fi

###############################################################################
# PRoot
###############################################################################

echo
echo "============================================"
echo "PROOT"
echo "============================================"

if runtime_ubuntu_ready; then
    check_ok "Ubuntu PRoot"
else
    check_fail "Ubuntu PRoot"
fi

if [[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/$RUNTIME_UBUNTU" ]] ||
   [[ -d "$PREFIX/var/lib/proot-distro/containers/$RUNTIME_UBUNTU/rootfs" ]]; then
    check_ok "Ubuntu rootfs"
else
    check_fail "Ubuntu rootfs"
fi

###############################################################################
# XFCE
###############################################################################

echo
echo "============================================"
echo "XFCE"
echo "============================================"

if runtime_xfce_running; then
    check_ok "XFCE session"
    check_ok "XFWM4"
    check_ok "XFDesktop"
    check_ok "XFCE Panel"
else
    check_warn "XFCE runtime"
fi

if runtime_ubuntu_dbus_running; then
    check_ok "XFCE D-Bus"
else
    check_warn "XFCE D-Bus"
fi

###############################################################################
# AUDIO
###############################################################################

echo
echo "============================================"
echo "AUDIO"
echo "============================================"

if runtime_pulse_host_ready; then
    check_ok "Termux PulseAudio"
else
    check_fail "Termux PulseAudio"
fi

if pulse_prepare_client; then
    check_ok "PulseAudio client configuration"
else
    check_fail "PulseAudio client configuration"
fi

if runtime_pulse_ubuntu_ready; then
    check_ok "Ubuntu → Termux PulseAudio"
else
    check_fail "Ubuntu → Termux PulseAudio"
fi

###############################################################################
# CONTROL RUNTIME
###############################################################################

echo
echo "============================================"
echo "CONTROL RUNTIME"
echo "============================================"

CONTROL_MODULE="$SCRIPT_DIR/modules/09-toolkit-control.sh"
XFCE_CONTROL_LOG="$PREFIX/tmp/nht-xfce-control.log"

if [[ -x "$CONTROL_MODULE" ]]; then
    check_ok "Control module"
else
    check_fail "Control module"
fi

"$CONTROL_MODULE" state >/dev/null 2>&1
CONTROL_STATE_RC=$?

if (( CONTROL_STATE_RC == 0 )); then
    check_ok "Control state"
else
    check_fail "Control state"
fi

if "$CONTROL_MODULE" check >/dev/null 2>&1; then
    check_ok "Control runtime"
else
    check_fail "Control runtime"
fi

if [[ -f "$XFCE_CONTROL_LOG" && -r "$XFCE_CONTROL_LOG" ]]; then
    # Ignore expected PRoot/Android/XFCE integration warnings.
    # Only classify clear startup/runtime failures as warnings.
    if grep -Eiq \
        '(^|[^[:alpha:]])(fatal|segmentation fault|cannot open display|can.t open display|failed to start (xfce|xfwm|xfdesktop)|failed to launch (xfce|xfwm|xfdesktop)|exec.*failed)([^[:alpha:]]|$)' \
        "$XFCE_CONTROL_LOG"
    then
        check_warn "XFCE control log has startup errors"
    else
        check_ok "XFCE control log"
    fi
else
    check_ok "XFCE control log (not active)"
fi


EXPECTED_XDG_RUNTIME_DIR="${PREFIX}/tmp"

if [[ "${XDG_RUNTIME_DIR:-}" == "$EXPECTED_XDG_RUNTIME_DIR" ]]; then
    check_ok "Host XDG_RUNTIME_DIR"
elif [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    check_ok "Host XDG_RUNTIME_DIR unset"
else
    check_warn "Host XDG_RUNTIME_DIR differs from Termux runtime"
fi

if [[ -z "${PULSE_SERVER:-}" &&
      -z "${PULSE_CLIENTCONFIG:-}" &&
      -z "${PULSE_COOKIE:-}" ]]; then
    check_ok "Host Pulse environment clean"
else
    check_warn "Host Pulse environment set"
fi

###############################################################################
# FILESYSTEM
###############################################################################

echo
echo "============================================"
echo "FILESYSTEM"
echo "============================================"

if [[ -d "$PREFIX/tmp" && -w "$PREFIX/tmp" ]]; then
    check_ok "Termux /tmp"
else
    check_fail "Termux /tmp"
fi

if [[ -d "$PREFIX/tmp/.X11-unix" ]]; then
    check_ok "X11 socket directory"
elif runtime_x11_running; then
    check_ok "X11 transport (TCP)"
else
    check_fail "X11 transport"
fi

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
    '[[ -d /tmp && -w /tmp ]]'
then
    check_ok "Ubuntu /tmp"
else
    check_fail "Ubuntu /tmp"
fi

###############################################################################
# SUMMARY
###############################################################################

echo
echo "============================================"
echo "DOCTOR SUMMARY"
echo "============================================"

echo "Godkända : $PASS"
echo "Varningar: $WARNINGS"
echo "Fel      : $FAILS"
echo

if (( FAILS > 0 )); then
    echo -e "${RED}[✗]${RESET} SYSTEM REQUIRES ATTENTION"
    exit 1
elif (( WARNINGS > 0 )); then
    echo -e "${YELLOW}[!]${RESET} SYSTEM HEALTHY WITH WARNINGS"
    exit 1
else
    echo -e "${GREEN}[✓]${RESET} SYSTEM HEALTHY"
    exit 0
fi
