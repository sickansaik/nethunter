#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Colors & Display
###############################################################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
RESET='\033[0m'

###############################################################################
# Status
###############################################################################

ok() {
    echo -e "${GREEN}[✓]${RESET} $1"
}

info() {
    echo -e "${BLUE}[i]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
    echo -e "${RED}[✗]${RESET} $1"
}

###############################################################################
# Titel
###############################################################################

title() {

    clear

    # Läs versionsinformation om den finns
    local version_file

    version_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/version.conf"

    if [[ -f "$version_file" ]]; then
        # shellcheck source=../config/version.conf
        source "$version_file"
    fi

    local name="${TOOLKIT_NAME:-NetHunter Toolkit}"
    local version="${TOOLKIT_VERSION:-unknown}"

    echo -e "${CYAN}"
    echo "============================================"
    echo "        ${name} v${version}"
    echo "============================================"
    echo -e "${RESET}"
}
