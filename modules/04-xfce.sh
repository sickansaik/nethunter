#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 04 - XFCE
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/runtime.sh"

title
log_info "Kontrollerar XFCE"

###############################################################################
# Existing installation
###############################################################################

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc \
    'for program in startxfce4 xfce4-session xfwm4 xfce4-panel xfdesktop dbus-launch dbus-run-session xdpyinfo pactl; do command -v "$program" >/dev/null 2>&1 || exit 1; done'
then
    log_ok "XFCE och nödvändiga GUI-/ljudverktyg redan installerade."
    log_ok "XFCE-kontroll klar."
    exit 0
fi

###############################################################################
# Clean-install bootstrap
###############################################################################

log_info "XFCE saknas. Installerar Ubuntu GUI-komponenter..."

if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc '
    set -e

    export DEBIAN_FRONTEND=noninteractive

    apt-get update

    apt-get install -y \
        xfce4-session \
        xfwm4 \
        xfce4-panel \
        xfdesktop4 \
        dbus-x11 \
        pulseaudio-utils \
        x11-utils
'
then
    log_error "XFCE-installationen misslyckades."
    exit 1
fi

###############################################################################
# Post-install verification
###############################################################################

log_info "Verifierar XFCE-installationen"

if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc \
    'for program in startxfce4 xfce4-session xfwm4 xfce4-panel xfdesktop dbus-launch dbus-run-session xdpyinfo pactl; do command -v "$program" >/dev/null 2>&1 || exit 1; done'
then
    log_error "Ett eller flera GUI-/ljudverktyg saknas efter installationen."
    exit 1
fi

log_ok "XFCE installerat."
log_ok "XFCE-kontroll klar."

exit 0
