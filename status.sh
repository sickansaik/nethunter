#!/data/data/com.termux/files/usr/bin/bash


# NetHunter Toolkit
# Status & Health Check
###############################################################################

set -u

PASS=0
WARNINGS=0
FAILS=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/lib/runtime.sh"

###############################################################################
# Header
###############################################################################

title

info "NetHunter Toolkit Status"
info "Version: $TOOLKIT_VERSION"

echo

###############################################################################
# Helper
###############################################################################

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
# Core
###############################################################################

echo "============================================"
echo "CORE"
echo "============================================"

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1; then
    check_ok "Ubuntu"
else
    check_fail "Ubuntu"
fi

if command -v termux-x11 >/dev/null 2>&1; then
    check_ok "Termux:X11 installerad"
else
    check_fail "Termux:X11"
fi

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
    'command -v startxfce4 >/dev/null 2>&1'
then
    check_ok "XFCE"
else
    check_fail "XFCE"
fi

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
    'command -v dbus-launch >/dev/null 2>&1'
then
    check_ok "DBus"
else
    check_fail "DBus"
fi

if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    check_ok "PulseAudio körs"
else
    if command -v pulseaudio >/dev/null 2>&1; then
        check_warn "PulseAudio inte aktivt"
        echo "    → PulseAudio är installerat och kan startas med ./repair.sh."
    else
        check_fail "PulseAudio saknas"
        echo "    → Kör ./repair.sh för diagnostik."
    fi
fi

###############################################################################
# X11
###############################################################################

if DISPLAY="$RUNTIME_X11_DISPLAY" xdpyinfo >/dev/null 2>&1; then
    check_ok "X11 / DISPLAY=$RUNTIME_X11_DISPLAY"
else
    check_warn "X11 / DISPLAY=$RUNTIME_X11_DISPLAY ej nåbar"
    echo "    → Termux:X11 verkar inte vara nåbar via Runtime TCP."
fi

###############################################################################
# Toolkit tools
###############################################################################

echo
echo "============================================"
echo "TOOLS"
echo "============================================"

TOOLS=(
    "install.sh"
    "repair.sh"
    "update.sh"
    "backup.sh"
    "restore.sh"
    "status.sh"
    "toolkit.sh"
    "cleanup.sh"
)

for tool in "${TOOLS[@]}"; do
    if [[ -x "$SCRIPT_DIR/$tool" ]]; then
        check_ok "$tool"
    else
        check_fail "$tool"
    fi
done

###############################################################################
# Config
###############################################################################

echo
echo "============================================"
echo "CONFIG"
echo "============================================"

check_ok "settings.conf"
check_ok "Display : $RUNTIME_X11_DISPLAY"
check_ok "Auto Repair : $AUTO_REPAIR"
check_ok "Auto Update : $AUTO_UPDATE"
check_ok "Backup retention : $KEEP_BACKUPS"
check_ok "Pre-restore retention : $KEEP_PRE_RESTORE"

###############################################################################
# Backups
###############################################################################

echo
echo "============================================"
echo "BACKUPS"
echo "============================================"

BACKUP_DIR="$SCRIPT_DIR/backups"

LATEST_BACKUP="$(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'nethunter-toolkit-*.tar.gz' \
        -printf '%T@ %f\n' 2>/dev/null |
    sort -nr |
    head -1 |
    cut -d' ' -f2-
)"

if [[ -n "$LATEST_BACKUP" ]]; then
    BACKUP_PATH="$SCRIPT_DIR/backups/$LATEST_BACKUP"

    if tar -tzf "$BACKUP_PATH" >/dev/null 2>&1; then
        check_ok "Senaste backup verifierad: $LATEST_BACKUP"
    else
        check_fail "Senaste backup är korrupt: $LATEST_BACKUP"
    fi
else
    check_warn "Ingen Toolkit-backup hittades."
fi

###############################################################################
# Summary
###############################################################################

echo
echo "============================================"
echo "STATUS SUMMARY"
echo "============================================"

check_ok "Statuskontroll klar."

echo
echo "Toolkit:"
echo "$TOOLKIT_NAME v$TOOLKIT_VERSION"

echo "Codename:"
echo "$TOOLKIT_CODENAME"

echo "Status:"
echo "$TOOLKIT_STATUS"

echo "============================================"

if (( FAILS > 0 )); then
    echo -e "${RED}[✗]${RESET} SYSTEM REQUIRES ATTENTION"
elif (( WARNINGS > 0 )); then
    echo -e "${YELLOW}[!]${RESET} SYSTEM OPERATIONAL WITH WARNINGS"
else
    echo -e "${GREEN}[✓]${RESET} SYSTEM OPERATIONAL"
fi

echo
echo "Godkända : $PASS"
echo "Varningar: $WARNINGS"
echo "Fel      : $FAILS"

###############################################################################
# Central System Status
###############################################################################

ENGINE_FAILURES=$FAILS
ENGINE_WARNINGS=$WARNINGS

echo
print_system_status
STATUS_ENGINE_EXIT=$?

echo
echo "============================================"
echo "        STATUS RESULT"
echo "============================================"
echo

if (( FAILS > 0 )); then
    STATUS_EXIT=1
    log_error "STATUS CHECK FAILED."
elif (( WARNINGS > 0 )); then
    STATUS_EXIT=0
    log_warn "STATUS CHECK GREEN WITH WARNINGS."
else
    STATUS_EXIT=0
    log_ok "STATUS CHECK GREEN."
fi

echo "STATUS_ENGINE_EXIT=$STATUS_ENGINE_EXIT"
echo "STATUS_EXIT=$STATUS_EXIT"

exit "$STATUS_EXIT"
