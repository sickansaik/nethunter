#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 06 - Developer Tools
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/runtime.sh"

title
log_info "Installerar utvecklingsverktyg"

PACKAGES=(
    git
    curl
    wget
    vim
    nano
    tmux
    zsh
    python3
    python3-pip
    python3-venv
    nodejs
    npm
    golang
    build-essential
    unzip
    zip
    jq
)

PACKAGE_LIST="${PACKAGES[*]}"

if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update &&
    apt-get install -y $PACKAGE_LIST
"; then
    log_ok "Utvecklingsverktyg installerade."
else
    log_error "Installationen av utvecklingsverktyg misslyckades."
    exit 1
fi

# Kontrollera några viktiga verktyg
VERIFY_WARNINGS=0

TOOLS=(
    git
    python3
    pip3
    node
    npm
    go
)

for tool in "${TOOLS[@]}"
do
    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "command -v $tool >/dev/null 2>&1"
    then
        log_ok "$tool OK"
    else
        log_warn "$tool kunde inte verifieras"
        ((VERIFY_WARNINGS+=1))
    fi
done

if (( VERIFY_WARNINGS > 0 )); then
    log_error "$VERIFY_WARNINGS utvecklingsverktyg kunde inte verifieras."
    exit 1
fi

exit 0
