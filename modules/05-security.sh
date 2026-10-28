#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 05 - Security Base
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/runtime.sh"

title
log_info "Installerar Security Base"

PACKAGES=(
    nmap
    sqlmap
    hydra
    gobuster
    ffuf
    netcat-openbsd
    tcpdump
    whois
    dnsutils
    curl
    wget
)

INSTALL_FAILURES=0

# Uppdatera paketlistan en gång innan loopen i stället för per paket.
# Snabbare och mindre nätverkstrafik; hoppas över om allt redan är installerat.
APT_UPDATED=0
apt_update_once()
{
    if (( APT_UPDATED == 0 )); then
        log_info "Uppdaterar paketlistan"
        runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "apt-get update >/dev/null" || true
        APT_UPDATED=1
    fi
}

for pkg in "${PACKAGES[@]}"
do

    log_info "Kontrollerar $pkg"

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "dpkg -s $pkg >/dev/null 2>&1"
    then
        log_ok "$pkg redan installerat."
        continue
    fi

    apt_update_once

    log_info "Installerar $pkg"

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg"
    then
        log_ok "$pkg installerades."
    else
        log_warn "$pkg kunde inte installeras."
        ((INSTALL_FAILURES+=1))
    fi

done

if (( INSTALL_FAILURES > 0 )); then
    log_error "$INSTALL_FAILURES säkerhetspaket kunde inte installeras."
    exit 1
fi

log_ok "Security Base klar."

exit 0
