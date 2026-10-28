#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Logging Library
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_DIR="$SCRIPT_DIR/logs"

# Standardlogg
LOG_FILE="${LOG_FILE:-$LOG_DIR/install.log}"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%F %T')] $1" >> "$LOG_FILE"
}

log_ok() {
    log "[ OK ] $1"
    ok "$1"
}

log_warn() {
    log "[WARN] $1"
    warn "$1"
}

log_error() {
    log "[FAIL] $1"
    error "$1"
}

log_info() {
    log "[INFO] $1"
    info "$1"
}
