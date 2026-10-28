#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Update Engine 2.0
#
# Pipeline:
#   Discover
#   Validate
#   Verify manifest
#   Backup
#   Stage
#   Apply
#   Verify
#   Doctor / status
#   Rollback on failure
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/lib/installation.sh"
LOCK_DIR="$SCRIPT_DIR/.installation-lock"
mkdir "$LOCK_DIR" 2>/dev/null || { log_error "En annan installationsåtgärd pågår, eller ett gammalt lås finns kvar."; exit 2; }
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
nht_require_installation "$SCRIPT_DIR" || exit 2

PREVIOUS_VERSION="$TOOLKIT_VERSION"

PASS=0
WARNINGS=0
FAILS=0

check_ok() {
    echo -e "${GREEN}[✓]${RESET} $1"
    ((PASS+=1))
}

check_warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
    ((WARNINGS+=1))
}

check_fail() {
    echo -e "${RED}[✗]${RESET} $1"
    ((FAILS+=1))
}

###############################################################################
# Configuration
###############################################################################

UPDATE_DIR="$SCRIPT_DIR/updates"
BACKUP_DIR="$SCRIPT_DIR/backups"

RUNTIME_ITEMS=("${NHT_INSTALL_ITEMS[@]}")

SHELL_FILES=(
    "feature.sh"
    "nht"
    "install.sh"
    "runtime/ubuntu-gui.sh"
    "repair.sh"
    "update.sh"
    "backup.sh"
    "restore.sh"
    "status.sh"
    "toolkit.sh"
    "cleanup.sh"
    "doctor.sh"
)

###############################################################################
# Version comparison
###############################################################################

version_is_newer() {
    local current="$1"
    local target="$2"

    [[ "$current" != "$target" ]] &&
    [[ "$(printf '%s\n' "$current" "$target" | sort -V | tail -1)" == "$target" ]]
}

###############################################################################
# Exact runtime cleanup
###############################################################################

remove_runtime_tree() {

    local item
    local target

    [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" != "/" ]] || return 1

    for item in "${RUNTIME_ITEMS[@]}" "${NHT_RELEASE_METADATA[@]}"; do
        [[ -n "$item" && "$item" != "." && "$item" != ".." ]] || return 1
        [[ "$item" != /* && "$item" != */../* && "$item" != ../* && "$item" != */.. ]] || return 1

        target="${SCRIPT_DIR:?}/$item"

        [[ "$target" == "$SCRIPT_DIR/"* ]] || return 1

        rm -rf -- "$target" || return 1
    done

    return 0
}

###############################################################################
# Persistent runtime state
###############################################################################

PERSISTENT_STATE_STAGE=""

preserve_persistent_state() {

    local source_dir="$SCRIPT_DIR/runtime/network"
    local temp_base
    local temp_dir

    PERSISTENT_STATE_STAGE=""

    # No generated network state is a valid condition.
    if [[ ! -d "$source_dir" ]]; then
        return 0
    fi

    temp_base="${TMPDIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp}"

    if [[ ! -d "$temp_base" ]]; then
        return 1
    fi

    temp_dir="$(
        mktemp -d "$temp_base/nht-update-state.XXXXXX"
    )" || return 1

    if ! cp -a "$source_dir" "$temp_dir/network"; then
        rm -rf "$temp_dir" 2>/dev/null || true
        return 1
    fi

    PERSISTENT_STATE_STAGE="$temp_dir"

    return 0
}


restore_persistent_state() {

    local staged_dir

    if [[ -z "${PERSISTENT_STATE_STAGE:-}" ]]; then
        return 0
    fi

    staged_dir="$PERSISTENT_STATE_STAGE/network"

    if [[ ! -d "$staged_dir" ]]; then
        return 1
    fi

    if ! mkdir -p "$SCRIPT_DIR/runtime"; then
        return 1
    fi

    # Generated installation state wins only for runtime/network.
    # Release-owned files such as runtime/ubuntu-gui.sh remain untouched.
    if ! rm -rf "$SCRIPT_DIR/runtime/network"; then
        return 1
    fi

    if ! cp -a "$staged_dir" "$SCRIPT_DIR/runtime/network"; then
        return 1
    fi

    rm -rf "$PERSISTENT_STATE_STAGE" 2>/dev/null || true
    PERSISTENT_STATE_STAGE=""

    return 0
}


cleanup_persistent_state_stage() {

    if [[ -n "${PERSISTENT_STATE_STAGE:-}" ]]; then
        rm -rf "$PERSISTENT_STATE_STAGE" 2>/dev/null || true
    fi

    PERSISTENT_STATE_STAGE=""

    return 0
}


###############################################################################
# Exact rollback
###############################################################################

rollback_update() {

    echo
    echo "============================================"
    echo "ROLLBACK"
    echo "============================================"
    echo

    if ! remove_runtime_tree; then
        echo "[✗] Failed to clear runtime tree"
        return 1
    fi

    if ! tar -xzf "$PRE_UPDATE_BACKUP" -C "$SCRIPT_DIR"; then
        echo "[✗] Previous version extraction failed"
        return 1
    fi

    if ! tar -dzf "$PRE_UPDATE_BACKUP" -C "$SCRIPT_DIR" >/dev/null 2>&1; then
        echo "[✗] Rollback content verification failed"
        return 1
    fi

    if [[ -f "$SCRIPT_DIR/config/version.conf" ]]; then
        source "$SCRIPT_DIR/config/version.conf"
    fi

    if [[ "${TOOLKIT_VERSION:-}" == "$PREVIOUS_VERSION" ]]; then
        echo "[✓] Previous version restored: $PREVIOUS_VERSION"
        return 0
    fi

    echo "[✗] Rollback version verification failed"
    return 1
}

###############################################################################
# Manifest validation
###############################################################################

verify_release_manifest() {

    local release_dir="$1"
    local manifest="$release_dir/release.manifest"

    if [[ ! -f "$manifest" ]]; then
        check_fail "release.manifest missing"
        return 1
    fi

    echo
    echo "Manifest checksum verification"

    if (
        cd "$release_dir" &&
        sha256sum -c release.manifest >/dev/null
    ); then
        check_ok "Manifest hashes valid"
    else
        check_fail "Manifest hash verification failed"
        return 1
    fi

    local expected actual

    expected="$(
        awk '{print $2}' "$manifest" |
        sort
    )"

    actual="$(
        find "$release_dir" -type f \
            ! -name 'release.manifest' \
            -printf './%P\n' |
        sort
    )"

    if [[ "$expected" != "$actual" ]]; then
        check_fail "Manifest file set mismatch"
        echo
        echo "--- Manifest expects ---"
        printf '%s\n' "$expected"
        echo
        echo "--- Release contains ---"
        printf '%s\n' "$actual"
        return 1
    fi

    check_ok "Manifest file set exact"

    return 0
}

###############################################################################
# Release validation
###############################################################################

validate_release() {

    local release_dir="$1"
    local item
    local file

    echo
    echo "============================================"
    echo "RELEASE VALIDATION"
    echo "============================================"

    if [[ -e "$release_dir/runtime/network" ]]; then
        check_fail "Release contains installation-owned network state"
        return 1
    fi
    if [[ -n "$(find "$release_dir" -type l -print -quit)" ]]; then
        check_fail "Release contains symbolic links"
        return 1
    fi

    for item in "${RUNTIME_ITEMS[@]}"; do

        if [[ -e "$release_dir/$item" ]]; then
            check_ok "$item"
        else
            check_fail "$item missing"
        fi

    done

    if (( FAILS > 0 )); then
        return 1
    fi

    echo
    echo "Release syntax"

    for file in "${SHELL_FILES[@]}"; do

        if bash -n "$release_dir/$file" >/dev/null 2>&1; then
            check_ok "$file syntax"
        else
            check_fail "$file syntax"
        fi

    done

    if (( FAILS > 0 )); then
        return 1
    fi

    nht_require_installation "$release_dir" || { check_fail "Incomplete installation"; return 1; }
    while IFS= read -r -d '' file; do
        bash -n "$file" || return 1
    done < <(find "$release_dir" -type f -name '*.sh' -print0)

    verify_release_manifest "$release_dir" || return 1

    return 0
}

###############################################################################
# Header
###############################################################################

echo
echo "============================================"
echo "        NetHunter Toolkit Update"
echo "             Update Engine 2.0"
echo "============================================"
echo

info "Current version: $TOOLKIT_VERSION"
info "Codename: $TOOLKIT_CODENAME"
info "Update source: $UPDATE_SOURCE"

###############################################################################
# Engine checks
###############################################################################

if [[ "$UPDATE_ENABLED" != "true" ]]; then
    log_error "Update engine disabled."
    exit 2
fi

if [[ "$UPDATE_SOURCE" != "local" ]]; then
    log_error "Unsupported update source: $UPDATE_SOURCE"
    exit 2
fi

if [[ ! -d "$UPDATE_DIR" ]]; then
    log_error "Update repository saknas."
    exit 2
fi

mkdir -p "$BACKUP_DIR"

###############################################################################
# Discover newest target
###############################################################################

echo
echo "============================================"
echo "TARGET VERSION"
echo "============================================"

TARGET_VERSION=""

for version_dir in "$UPDATE_DIR"/*; do

    [[ -d "$version_dir" ]] || continue

    version="$(basename "$version_dir")"

    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

        if [[ -z "$TARGET_VERSION" ]]; then
            TARGET_VERSION="$version"
        elif [[ "$(printf '%s\n' "$TARGET_VERSION" "$version" | sort -V | tail -1)" == "$version" ]]; then
            TARGET_VERSION="$version"
        fi

    fi

done

if [[ -z "$TARGET_VERSION" ]]; then
    check_ok "Ingen uppdatering tillgänglig"
    exit 0
fi

check_ok "Target version: $TARGET_VERSION"

###############################################################################
# Version check
###############################################################################

echo
echo "============================================"
echo "VERSION CHECK"
echo "============================================"

if ! version_is_newer "$TOOLKIT_VERSION" "$TARGET_VERSION"; then
    check_ok "Ingen nyare version"
    exit 0
fi

check_ok "Update available"

RELEASE_DIR="$UPDATE_DIR/$TARGET_VERSION"

###############################################################################
# Validate release
###############################################################################

if ! validate_release "$RELEASE_DIR"; then
    log_error "Release validation failed."
    exit 2
fi

###############################################################################
# Pre-update backup
###############################################################################

echo
echo "============================================"
echo "PRE-UPDATE BACKUP"
echo "============================================"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')-$$"

PRE_UPDATE_BACKUP="$BACKUP_DIR/nethunter-toolkit-pre-update-$TIMESTAMP.tar.gz"

nht_backup_items "$SCRIPT_DIR"
if tar -czf "$PRE_UPDATE_BACKUP" -C "$SCRIPT_DIR" "${NHT_BACKUP_ITEMS[@]}"
then
    check_ok "Pre-update backup created"
else
    check_fail "Pre-update backup failed"
fi

if (( FAILS > 0 )); then
    log_error "UPDATE BLOCKED"
    exit 2
fi

if nht_verify_backup "$PRE_UPDATE_BACKUP"; then
    check_ok "Pre-update backup verified"
else
    rm -f -- "$PRE_UPDATE_BACKUP"
    log_error "Pre-update backup verification failed"
    exit 2
fi

###############################################################################
# Stage
###############################################################################

echo
echo "============================================"
echo "STAGING"
echo "============================================"

STAGE_DIR="$(mktemp -d "$SCRIPT_DIR/.update-stage-$TARGET_VERSION.XXXXXX")" || exit 2
trap 'rm -rf -- "$STAGE_DIR"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT



if cp -a "$RELEASE_DIR/." "$STAGE_DIR/"; then
    check_ok "Release staged"
    validate_release "$STAGE_DIR" || { rm -rf "$STAGE_DIR"; exit 2; }
else
    log_error "Failed to stage release"
    rm -rf "$STAGE_DIR"
    exit 2
fi

###############################################################################
# Apply
###############################################################################

echo
echo "============================================"
echo "APPLY UPDATE"
echo "============================================"

APPLY_FAILED=false

if ! preserve_persistent_state; then
    check_fail "Failed to preserve persistent runtime state"
    APPLY_FAILED=true
else
    check_ok "Persistent runtime state preserved"
fi

if [[ "$APPLY_FAILED" == "false" ]]; then

    if ! remove_runtime_tree; then
        check_fail "Failed to clear current runtime"
        APPLY_FAILED=true
    fi

fi

if [[ "$APPLY_FAILED" == "false" ]]; then

    for item in "${RUNTIME_ITEMS[@]}"; do

        if cp -a "$STAGE_DIR/$item" "$SCRIPT_DIR/$item"; then
            check_ok "Applied $item"
        else
            check_fail "Failed to apply $item"
            APPLY_FAILED=true
            break
        fi

    done

fi

if [[ "$APPLY_FAILED" == "false" ]]; then

    while IFS= read -r -d '' file; do
        chmod +x "$file" || APPLY_FAILED=true
    done < <(find "$SCRIPT_DIR/lib" "$SCRIPT_DIR/modules" "$SCRIPT_DIR/runtime" -type f -name '*.sh' -print0)
    for item in "${RUNTIME_ITEMS[@]}"; do
        [[ ! -f "$SCRIPT_DIR/$item" ]] || chmod +x "$SCRIPT_DIR/$item" || APPLY_FAILED=true
    done

    if restore_persistent_state; then
        check_ok "Persistent runtime state restored"
    else
        check_fail "Failed to restore persistent runtime state"
        APPLY_FAILED=true
    fi

fi

if [[ "$APPLY_FAILED" == "true" ]]; then
    cleanup_persistent_state_stage
fi

###############################################################################
# Apply failure
###############################################################################

if [[ "$APPLY_FAILED" == "true" ]]; then

    log_error "Update application failed."

    if rollback_update; then
        log_warn "UPDATE ROLLED BACK"
        exit 3
    else
        log_error "CRITICAL: ROLLBACK FAILED"
        exit 4
    fi

fi

###############################################################################
# Post-update verification
###############################################################################

echo
echo "============================================"
echo "POST-UPDATE VERIFICATION"
echo "============================================"

POST_VERSION=""

if [[ -f "$SCRIPT_DIR/config/version.conf" ]]; then
    source "$SCRIPT_DIR/config/version.conf"
    POST_VERSION="$TOOLKIT_VERSION"
fi

if [[ "$POST_VERSION" == "$TARGET_VERSION" ]]; then
    check_ok "Installed version: $POST_VERSION"
else
    check_fail "Version mismatch: $POST_VERSION"
fi

if bash -n "$SCRIPT_DIR/nht" >/dev/null 2>&1; then
    check_ok "Installed nht syntax"
else
    check_fail "Installed nht syntax"
fi

if bash -n "$SCRIPT_DIR/doctor.sh" >/dev/null 2>&1; then
    check_ok "Installed doctor syntax"
else
    check_fail "Installed doctor syntax"
fi

###############################################################################
# Installed runtime tree verification
###############################################################################

for item in "${RUNTIME_ITEMS[@]}"; do

    if [[ -e "$SCRIPT_DIR/$item" ]]; then
        check_ok "Installed $item"
    else
        check_fail "Installed $item missing"
    fi

done

###############################################################################
# Doctor / status verification
###############################################################################

STATUS_EXIT=0

"$SCRIPT_DIR/status.sh" >/dev/null 2>&1 || STATUS_EXIT=$?

case "$STATUS_EXIT" in
    0)
        check_ok "System status GREEN"
        ;;
    1)
        check_warn "System status GREEN WITH WARNINGS"
        ;;
    *)
        check_fail "System status FAILED (exit=$STATUS_EXIT)"
        ;;
esac

DOCTOR_EXIT=0

"$SCRIPT_DIR/doctor.sh" >/dev/null 2>&1 || DOCTOR_EXIT=$?

case "$DOCTOR_EXIT" in
    0)
        check_ok "Doctor GREEN"
        ;;
    1)
        check_warn "Doctor GREEN WITH WARNINGS"
        ;;
    *)
        check_fail "Doctor FAILED (exit=$DOCTOR_EXIT)"
        ;;
esac

###############################################################################
# Final failure / rollback
###############################################################################

if (( FAILS > 0 )); then

    log_error "Post-update verification failed."

    if rollback_update; then
        log_warn "UPDATE ROLLED BACK"
        exit 3
    else
        log_error "CRITICAL: ROLLBACK FAILED"
        exit 4
    fi

fi

###############################################################################
# Final result
###############################################################################

echo
echo "============================================"
echo "        UPDATE RESULT"
echo "============================================"
echo

echo "Previous version : $PREVIOUS_VERSION"
echo "Installed version: $POST_VERSION"
echo
echo "Godkända         : $PASS"
echo "Varningar        : $WARNINGS"
echo "Fel              : $FAILS"

echo

for metadata in "${NHT_RELEASE_METADATA[@]}"; do
    if [[ -f "$STAGE_DIR/$metadata" ]]; then
        if ! cp -a "$STAGE_DIR/$metadata" "$SCRIPT_DIR/$metadata"; then
            log_error "Failed to install release metadata"
            if rollback_update; then exit 3; else exit 4; fi
        fi
    fi
done

log_ok "UPDATE GREEN"
exit 0
