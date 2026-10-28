#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# NetHunter Toolkit
# Network Snapshot Engine
# v0.5.0 — STEP 4F-B
# ============================================================

NETWORK_SNAPSHOT_RUNTIME_DIR="${NHT_RUNTIME_DIR:-./runtime}/network"
NETWORK_SNAPSHOT_DIR="$NETWORK_SNAPSHOT_RUNTIME_DIR/snapshots"
NETWORK_SNAPSHOT_LATEST="$NETWORK_SNAPSHOT_RUNTIME_DIR/latest.json"


network_snapshot_runtime_dir() {
    printf '%s\n' "$NETWORK_SNAPSHOT_RUNTIME_DIR"
}


network_snapshot_dir() {
    printf '%s\n' "$NETWORK_SNAPSHOT_DIR"
}


network_snapshot_latest_path() {
    printf '%s\n' "$NETWORK_SNAPSHOT_LATEST"
}


network_snapshot_prepare() {

    mkdir -p "$NETWORK_SNAPSHOT_DIR" || return 1

    [[ -d "$NETWORK_SNAPSHOT_RUNTIME_DIR" ]] || return 1
    [[ -d "$NETWORK_SNAPSHOT_DIR" ]] || return 1

    return 0
}


network_snapshot_timestamp() {
    date '+%Y%m%d-%H%M%S'
}


network_snapshot_filename() {

    local timestamp
    local base
    local candidate
    local counter=0

    timestamp="$(network_snapshot_timestamp)" || return 1

    base="network-${timestamp}"
    candidate="${base}.json"

    while [[ -e "$NETWORK_SNAPSHOT_DIR/$candidate" ]]; do
        counter=$((counter + 1))
        candidate="${base}-${counter}.json"
    done

    printf '%s\n' "$candidate"
}


network_snapshot_validate() {

    local json="${1:-}"

    [[ -n "$json" ]] || return 1

    if declare -F network_data_validate_json >/dev/null 2>&1; then
        network_data_validate_json "$json" || return 1
    else
        return 1
    fi

    printf '%s\n' "$json" | python -c '
import json
import sys

data = json.load(sys.stdin)

assert data.get("schema") == "nht.network.v1"
assert data.get("mode") == "read-only"
assert data.get("scope") == "local-network-diagnostics"
assert isinstance(data.get("environment"), dict)
assert isinstance(data.get("connectivity", {}).get("ipv4_internet"), bool)
assert isinstance(data.get("ipv6", {}).get("detected"), bool)
assert isinstance(data.get("tools"), list)
' >/dev/null 2>&1
}


network_snapshot_write_file() {

    local target="${1:-}"
    local json="${2:-}"
    local temp_file

    [[ -n "$target" ]] || return 1
    [[ -n "$json" ]] || return 1

    temp_file="${target}.tmp.$$"

    rm -f "$temp_file" 2>/dev/null || true

    if ! printf '%s\n' "$json" > "$temp_file"; then
        rm -f "$temp_file" 2>/dev/null || true
        return 1
    fi

    if ! mv -f "$temp_file" "$target"; then
        rm -f "$temp_file" 2>/dev/null || true
        return 1
    fi

    return 0
}


network_snapshot_save() {

    local json="${1:-}"
    local filename
    local snapshot_path

    [[ -n "$json" ]] || return 1

    if ! network_snapshot_validate "$json"; then
        return 1
    fi

    if ! network_snapshot_prepare; then
        return 1
    fi

    filename="$(network_snapshot_filename)" || return 1

    snapshot_path="$NETWORK_SNAPSHOT_DIR/$filename"

    if ! network_snapshot_write_file "$snapshot_path" "$json"; then
        return 1
    fi

    if ! network_snapshot_write_file "$NETWORK_SNAPSHOT_LATEST" "$json"; then
        rm -f "$snapshot_path" 2>/dev/null || true
        return 1
    fi

    printf '%s\n' "$snapshot_path"

    return 0
}


network_snapshot_latest() {

    [[ -f "$NETWORK_SNAPSHOT_LATEST" ]] || return 1

    local json

    json="$(cat "$NETWORK_SNAPSHOT_LATEST")" || return 1

    network_snapshot_validate "$json" || return 1

    printf '%s\n' "$json"
}


network_snapshot_list() {

    [[ -d "$NETWORK_SNAPSHOT_DIR" ]] || return 0

    find "$NETWORK_SNAPSHOT_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'network-*.json' \
        -print \
        2>/dev/null \
        | sort
}
