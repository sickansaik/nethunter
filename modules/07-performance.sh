#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 07 - Performance & Verification
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/runtime.sh"

title
log_info "Verifierar installationen"

###############################################################################
# Grundläggande kontroller
###############################################################################

VERIFY_FAILURES=0

CHECKS=(
    "startxfce4"
    "dbus-launch"
    "python3"
    "git"
    "curl"
)

for cmd in "${CHECKS[@]}"
do
    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        "command -v $cmd >/dev/null 2>&1"
    then
        log_ok "$cmd OK"
    else
        log_warn "$cmd saknas"
        ((VERIFY_FAILURES+=1))
    fi
done

###############################################################################
# Termux:X11 installation
###############################################################################

echo

log_info "Kontrollerar Termux:X11"

if command -v termux-x11 >/dev/null 2>&1; then
    log_ok "termux-x11 OK"
else
    log_warn "termux-x11 saknas"
    ((VERIFY_FAILURES+=1))
fi

###############################################################################
# Ubuntu → Termux:X11 runtime verification
#
# En clean installation kräver inte att GUI-runtime redan är aktiv.
# lib/runtime.sh är single source of truth för DISPLAY och X11-transport.
###############################################################################

echo

log_info "Kontrollerar Ubuntu → Termux:X11"

if runtime_x11_running; then

    log_ok "Termux:X11 runtime är aktiv."
    log_info "Verifierar Ubuntu → Termux:X11 via $RUNTIME_X11_DISPLAY"

    if runtime_ubuntu_x11_test; then
        log_ok "Ubuntu kan ansluta till Termux:X11."
        log_ok "DISPLAY=$RUNTIME_X11_DISPLAY fungerar."
    else
        log_warn "Ubuntu kan inte verifiera den aktiva X11-runtime-miljön."
        ((VERIFY_FAILURES+=1))
    fi

else

    log_warn "Termux:X11 runtime är inte aktiv."
    log_info "Live Ubuntu → X11-test hoppas över under installation."
    log_info "Runtime-verifiering görs när GUI-sessionen startas."

fi

###############################################################################
# Sammanfattning
###############################################################################

echo

if (( VERIFY_FAILURES > 0 )); then
    log_error "$VERIFY_FAILURES verifieringskontroller misslyckades."
    exit 1
fi

log_ok "Verifiering klar."
exit 0
