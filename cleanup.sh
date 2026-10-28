#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Cleanup System
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/config/settings.conf"

LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/cleanup.log"
BACKUP_DIR="$SCRIPT_DIR/backups"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%F %T')] $1" >> "$LOG_FILE"
}

###############################################################################
# Configuration
###############################################################################

STABLE_BACKUP="$BACKUP_DIR/nethunter-toolkit-v0.1.0-stable.tar.gz"

###############################################################################
# Header
###############################################################################

title

info "NetHunter Toolkit Cleanup"
info "Version: $TOOLKIT_VERSION"

echo

###############################################################################
# Check backup directory
###############################################################################

if [[ ! -d "$BACKUP_DIR" ]]; then
    error "Backup-katalogen saknas."
    exit 1
fi

###############################################################################
# Stable checkpoint
###############################################################################

echo "============================================"
echo "STABLE CHECKPOINT"
echo "============================================"

if [[ -f "$STABLE_BACKUP" ]]; then
    ok "Stable checkpoint skyddad."
    info "$(basename "$STABLE_BACKUP")"
    log "[ OK ] Stable checkpoint protected."
else
    warn "Stable checkpoint saknas."
    log "[WARN] Stable checkpoint missing."
fi

echo

###############################################################################
# Find regular backups
###############################################################################

mapfile -t BACKUPS < <(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'nethunter-toolkit-*.tar.gz' \
        ! -name 'nethunter-toolkit-v0.1.0-stable.tar.gz' \
        ! -name 'pre-restore-*.tar.gz' \
        -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    cut -d' ' -f2-
)

###############################################################################
# Find pre-restore backups
###############################################################################

mapfile -t PRE_RESTORE < <(
    find "$BACKUP_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'pre-restore-*.tar.gz' \
        -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    cut -d' ' -f2-
)

DELETE_LIST=()

if (( ${#BACKUPS[@]} > KEEP_BACKUPS )); then
    for ((i=KEEP_BACKUPS; i<${#BACKUPS[@]}; i++)); do
        DELETE_LIST+=("${BACKUPS[$i]}")
    done
fi

if (( ${#PRE_RESTORE[@]} > KEEP_PRE_RESTORE )); then
    for ((i=KEEP_PRE_RESTORE; i<${#PRE_RESTORE[@]}; i++)); do
        DELETE_LIST+=("${PRE_RESTORE[$i]}")
    done
fi

###############################################################################
# Nothing to clean
###############################################################################

if (( ${#DELETE_LIST[@]} == 0 )); then
    ok "Inget behöver städas."
    log "[ OK ] Nothing to clean."
    exit 0
fi

###############################################################################
# Show deletion list
###############################################################################

echo "============================================"
echo "FILES TO DELETE"
echo "============================================"

for file in "${DELETE_LIST[@]}"; do
    warn "$(basename "$file")"
done

echo
info "Behåller senaste $KEEP_BACKUPS vanliga backuper."
info "Behåller senaste $KEEP_PRE_RESTORE pre-restore-backuper."

echo
echo "Stable checkpoint:"
echo "  [SKYDDAD] $(basename "$STABLE_BACKUP")"

echo
read -r -p "Fortsätt med rensningen? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo
    info "Rensningen avbruten."
    log "[INFO] Cleanup cancelled by user."
    exit 0
fi

###############################################################################
# Delete
###############################################################################

echo

DELETED=0
FAILED=0

for file in "${DELETE_LIST[@]}"; do
    if [[ -f "$file" ]]; then
        if rm -f -- "$file"; then
            ok "Raderad: $(basename "$file")"
            log "[ OK ] Deleted: $(basename "$file")"
            ((DELETED+=1))
        else
            error "Kunde inte radera: $(basename "$file")"
            log "[FAIL] Could not delete: $(basename "$file")"
            ((FAILED+=1))
        fi
    fi
done

###############################################################################
# Summary
###############################################################################

echo
echo "============================================"
echo "Cleanup Summary"
echo "============================================"

if (( FAILED > 0 )); then
    error "Cleanup avslutad med fel."
else
    ok "Cleanup klar."
fi

echo
echo "Raderade : $DELETED"
echo "Misslyckades: $FAILED"
echo
echo "Stable checkpoint:"
echo "  $(basename "$STABLE_BACKUP")"
echo
echo "Logg:"
echo "$LOG_FILE"
echo "============================================"

if (( FAILED > 0 )); then
    exit 1
else
    exit 0
fi
