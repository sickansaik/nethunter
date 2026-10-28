#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 02 - Ubuntu
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/runtime.sh"

title
log_info "Ubuntu-modul"

# Ubuntu fungerar redan om vi kan logga in i containern.
if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1; then
    log_ok "Ubuntu är redan installerad."
    exit 0
fi

log_info "Ubuntu hittades inte. Installerar..."

if proot-distro install ubuntu; then
    log_ok "Ubuntu installerades."
    exit 0
fi

log_error "Kunde inte installera Ubuntu."
exit 1
