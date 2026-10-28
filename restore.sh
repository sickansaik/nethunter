#!/data/data/com.termux/files/usr/bin/bash

# Restore is staged and verified before the live installation is touched.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"
LOG_FILE="$SCRIPT_DIR/logs/restore.log"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/installation.sh"
BACKUP_DIR="$SCRIPT_DIR/backups"

command -v python >/dev/null 2>&1 || { log_error "Python krävs för säker arkivkontroll."; exit 2; }
mkdir -p "$BACKUP_DIR" || exit 2
mapfile -t BACKUPS < <(find "$BACKUP_DIR" -maxdepth 1 -type f \
    \( -name 'nethunter-toolkit-*.tar.gz' -o -name 'pre-restore-*.tar.gz' \) -printf '%f\n' | sort -r)
if [[ ${#BACKUPS[@]} -eq 0 ]]; then
    log_error "Inga backuper hittades."
    exit 1
fi
for i in "${!BACKUPS[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${BACKUPS[$i]}"
done
read -r -p "Välj backup [1-${#BACKUPS[@]}]: " CHOICE || exit 1
# Limit digits before arithmetic and force decimal (08 is a valid selection).
if [[ ! "$CHOICE" =~ ^[0-9]{1,6}$ ]]; then exit 1; fi
CHOICE=$((10#$CHOICE))
if (( CHOICE < 1 || CHOICE > ${#BACKUPS[@]} )); then exit 1; fi
BACKUP_FILE="$BACKUP_DIR/${BACKUPS[$((CHOICE - 1))]}"

# Shared with update and backup. A stale lock after interruption needs inspection.
LOCK_DIR="$SCRIPT_DIR/.installation-lock"
mkdir "$LOCK_DIR" 2>/dev/null || { log_error "En annan installationsåtgärd pågår, eller ett gammalt lås finns kvar."; exit 2; }
STAGE_DIR=""
cleanup_restore() {
    [[ -z "$STAGE_DIR" ]] || rm -rf -- "$STAGE_DIR"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup_restore EXIT
STAGE_DIR="$(mktemp -d "$SCRIPT_DIR/.restore-stage.XXXXXX")" || exit 2
if ! nht_extract_backup "$BACKUP_FILE" "$STAGE_DIR" || ! nht_require_installation "$STAGE_DIR"; then
    log_error "Backupen är osäker, ofullständig eller ogiltig. Inga installationsfiler har ändrats."
    exit 2
fi
while IFS= read -r -d '' file; do
    bash -n "$file" || exit 2
done < <(find "$STAGE_DIR" -type f \( -name '*.sh' -o -name nht \) -print0)
read -r -p "Ersätt installationen och nätverkshistoriken med vald backup? [y/N]: " CONFIRM || exit 1
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

nht_require_installation "$SCRIPT_DIR" || exit 2
nht_backup_items "$SCRIPT_DIR"
SAFETY_BACKUP="$BACKUP_DIR/pre-restore-$(date '+%Y-%m-%d_%H-%M-%S')-$$.tar.gz"
if ! tar -czf "$SAFETY_BACKUP" -C "$SCRIPT_DIR" "${NHT_BACKUP_ITEMS[@]}" ||
   ! nht_verify_backup "$SAFETY_BACKUP"; then
    rm -f -- "$SAFETY_BACKUP"
    log_error "Kunde inte skapa och verifiera säkerhetskopian."
    exit 2
fi

replace_installation() {
    local root="$1" item
    for item in "${NHT_INSTALL_ITEMS[@]}" "${NHT_RELEASE_METADATA[@]}"; do
        rm -rf -- "${SCRIPT_DIR:?}/$item" || return 1
        if [[ -e "$root/$item" ]]; then
            cp -a "$root/$item" "$SCRIPT_DIR/$item" || return 1
        fi
    done
}
rollback_restore() {
    local rollback_dir
    rollback_dir="$(mktemp -d "$SCRIPT_DIR/.restore-rollback.XXXXXX")" || return 1
    if nht_extract_backup "$SAFETY_BACKUP" "$rollback_dir" && replace_installation "$rollback_dir" &&
       tar -dzf "$SAFETY_BACKUP" -C "$SCRIPT_DIR" >/dev/null 2>&1; then
        rm -rf -- "$rollback_dir"
        return 0
    fi
    log_error "Återgången misslyckades. Bevarad arbetskopia: $rollback_dir"
    return 1
}

RESTORE_FAILED=false
replace_installation "$STAGE_DIR" || RESTORE_FAILED=true
if [[ "$RESTORE_FAILED" == false ]]; then
    find "$SCRIPT_DIR/lib" "$SCRIPT_DIR/modules" "$SCRIPT_DIR/runtime" -type f -name '*.sh' -exec chmod +x {} + || RESTORE_FAILED=true
    for item in "${NHT_INSTALL_ITEMS[@]}"; do
        [[ ! -f "$SCRIPT_DIR/$item" ]] || chmod +x "$SCRIPT_DIR/$item" || RESTORE_FAILED=true
    done
    # Invoke via Bash so diagnostics do not depend on archive executable bits.
    VERIFY_RC=0
    bash "$SCRIPT_DIR/repair.sh" || VERIFY_RC=$?
    case "$VERIFY_RC" in
        0) ;;
        1) log_warn "Återställd installation har driftvarningar." ;;
        *) RESTORE_FAILED=true ;;
    esac
fi
if [[ "$RESTORE_FAILED" == true ]]; then
    log_error "Återställningen misslyckades. Återgår till säkerhetskopian."
    if rollback_restore; then exit 3; else exit 4; fi
fi
log_ok "Restore klar. Säkerhetskopia: $SAFETY_BACKUP"
exit 0
