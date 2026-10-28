#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Backup System
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Configuration
###############################################################################

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"

LOG_FILE="$SCRIPT_DIR/logs/backup.log"

source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/installation.sh"
LOCK_DIR="$SCRIPT_DIR/.installation-lock"
mkdir "$LOCK_DIR" 2>/dev/null || { log_error "En annan installationsåtgärd pågår, eller ett gammalt lås finns kvar."; exit 2; }
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
nht_require_installation "$SCRIPT_DIR" || exit 2

###############################################################################
# Header
###############################################################################

title

log_info "NetHunter Toolkit Backup"
log_info "Version: $TOOLKIT_VERSION"

echo

###############################################################################
# Backup directory
###############################################################################

BACKUP_DIR="$SCRIPT_DIR/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')-$$"
BACKUP_FILE="$BACKUP_DIR/nethunter-toolkit-$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR" || exit 1

###############################################################################
# Files to backup
###############################################################################

nht_backup_items "$SCRIPT_DIR"
ITEMS=("${NHT_BACKUP_ITEMS[@]}")

###############################################################################
# Verify files
MISSING=0
###############################################################################

log_info "Kontrollerar filer..."

for item in "${ITEMS[@]}"; do

    if [[ -e "$SCRIPT_DIR/$item" ]]; then
        log_ok "$item OK"
    else
        log_error "$item saknas"
        ((MISSING+=1))
    fi

done

if (( MISSING > 0 )); then
    echo
    log_error "Backup avbruten: $MISSING obligatoriska objekt saknas."
    exit 1
fi

###############################################################################
# Create backup
###############################################################################

echo

log_info "Skapar backup..."

if tar -czf "$BACKUP_FILE" -C "$SCRIPT_DIR" "${ITEMS[@]}"; then

    log_ok "Backup skapad."

else

    rm -f -- "$BACKUP_FILE"
    log_error "Backup misslyckades."
    exit 1

fi

###############################################################################
# Verify backup
###############################################################################

echo

log_info "Verifierar backup..."

if [[ -s "$BACKUP_FILE" ]] && nht_verify_backup "$BACKUP_FILE"; then

    BACKUP_SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"

    log_ok "Backup verifierad."
    log_info "Storlek: $BACKUP_SIZE"

else

    rm -f -- "$BACKUP_FILE"
    log_error "Backupen är tom, osäker eller ofullständig."
    exit 1

fi

###############################################################################
# Summary
###############################################################################

echo

echo "============================================"
echo "        Backup Summary"
echo "============================================"

log_ok "Backup klar."

echo
echo "Fil:"
echo "$BACKUP_FILE"

echo
echo "Storlek:"
echo "$BACKUP_SIZE"

echo
echo "Logg:"
echo "$LOG_FILE"

echo "============================================"

exit 0
