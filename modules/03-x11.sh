#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 03 - Termux:X11
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"

title

log_info "Kontrollerar Termux:X11"

if command -v termux-x11 >/dev/null 2>&1
then
    log_ok "termux-x11 installerad."
else
    log_error "termux-x11 saknas."

    echo
    echo "Installera med:"
    echo
    echo "pkg install x11-repo"
    echo "pkg install termux-x11-nightly"

    exit 1
fi

log_ok "X11-kontroll klar."

exit 0
