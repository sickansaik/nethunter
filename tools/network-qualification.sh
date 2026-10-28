#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf "%s\n" "NETWORK QUALIFICATION: RED — not a Git repository" >&2
    exit 1
}

cd "$ROOT" || exit 1

PASS=0
FAIL=0

pass() {
    printf "PASS: %s\n" "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf "FAIL: %s\n" "$1" >&2
    FAIL=$((FAIL + 1))
}

run_action() {
    local action="$1"

    if ./modules/features/network.sh "$action" >/dev/null 2>&1; then
        pass "network action: $action"
    else
        fail "network action: $action"
    fi
}

network_snapshot_rollback_test() {
    local test_root
    local rc

    test_root="${TMPDIR:-$PREFIX/tmp}/nht-rollback-test-$$"
    rm -rf "$test_root" 2>/dev/null || true

    if ! mkdir -p "$test_root"; then
        return 1
    fi

    NHT_RUNTIME_DIR="$test_root/runtime"         bash -c '
            source "./lib/network/data.sh"
            source "./lib/network/snapshot.sh"

            network_snapshot_write_file() {
                local target="${1:-}"
                local json="${2:-}"

                if [[ "$target" == "$NETWORK_SNAPSHOT_LATEST" ]]; then
                    return 1
                fi

                printf "%s\\n" "$json" > "$target"
            }

            json="$(network_data_json test0 192.168.1.10 192.168.1.1 192.168.1.0/24)"

            if network_snapshot_save "$json" >/dev/null 2>&1; then
                exit 10
            fi

            count="$(
                find "$NETWORK_SNAPSHOT_DIR"                     -maxdepth 1                     -type f                     -name "network-*.json"                     2>/dev/null |
                    wc -l |
                    tr -d " "
            )"

            [[ "$count" == "0" ]] || exit 11
            [[ ! -e "$NETWORK_SNAPSHOT_LATEST" ]] || exit 12
        '

    rc=$?

    rm -rf "$test_root" 2>/dev/null || true

    return "$rc"
}

printf "%s\n" \
    "============================================================" \
    "        NetHunter Toolkit — Network Qualification" \
    "============================================================" \
    ""

printf "%s\n" "=== FEATURE REGISTRATION ==="

if ./feature.sh info network >/dev/null 2>&1; then
    pass "network feature registration"
else
    fail "network feature registration"
fi

printf "%s\n" "" "=== FEATURE ACTIONS ==="

for action in \
    intelligence \
    scan \
    quick \
    standard \
    diagnostic \
    tools \
    report
do
    run_action "$action"
done

printf "%s\n" "" "=== DATA CONTRACT ==="

json_output="$(./modules/features/network.sh json 2>/dev/null)" || json_output=""

if [[ -n "$json_output" ]]; then
    pass "network JSON output"
else
    fail "network JSON output"
fi

if [[ -n "$json_output" ]] &&
   printf "%s\n" "$json_output" | python -m json.tool >/dev/null 2>&1; then
    pass "network JSON validity"
else
    fail "network JSON validity"
fi

if [[ -n "$json_output" ]] &&
   printf "%s\n" "$json_output" | python -c '
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
' >/dev/null 2>&1; then
    pass "network JSON semantic contract"
else
    fail "network JSON semantic contract"
fi

printf "%s\n" "" "=== SNAPSHOT CONTRACT ==="

snapshot_output="$(./modules/features/network.sh snapshot 2>/dev/null)" || snapshot_output=""

if [[ -n "$snapshot_output" ]]; then
    pass "network snapshot creation"
else
    fail "network snapshot creation"
fi

if [[ -n "$snapshot_output" && -f "$snapshot_output" ]]; then
    pass "network snapshot file"
else
    fail "network snapshot file"
fi

snapshot_json="$(cat "$snapshot_output" 2>/dev/null)" || snapshot_json=""

if [[ -n "$snapshot_json" ]] &&
   printf "%s\n" "$snapshot_json" | python -c '
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
' >/dev/null 2>&1; then
    pass "network snapshot semantic contract"
else
    fail "network snapshot semantic contract"
fi

if ./modules/features/network.sh snapshots >/dev/null 2>&1; then
    pass "network snapshot listing"
else
    fail "network snapshot listing"
fi

if ./modules/features/network.sh latest >/dev/null 2>&1; then
    pass "network latest snapshot"
else
    fail "network latest snapshot"
fi

latest_json="$(./modules/features/network.sh latest 2>/dev/null)" || latest_json=""

if [[ -n "$snapshot_json" && -n "$latest_json" &&
      "$snapshot_json" == "$latest_json" ]]; then
    pass "network latest snapshot integrity"
else
    fail "network latest snapshot integrity"
fi

if [[ -n "$snapshot_output" ]] &&
   ./modules/features/network.sh validate "$snapshot_output" >/dev/null 2>&1; then
    pass "network snapshot validation CLI"
else
    fail "network snapshot validation CLI"
fi

invalid_snapshot="${TMPDIR:-$PREFIX/tmp}/nht-invalid-network-snapshot-$$.json"
printf '%s\n' '{"schema":"nht.network.v1","mode":"corrupt"}' > "$invalid_snapshot"

if ./modules/features/network.sh validate "$invalid_snapshot" >/dev/null 2>&1; then
    fail "network snapshot validation rejects invalid data"
else
    pass "network snapshot validation rejects invalid data"
fi

rm -f "$invalid_snapshot" 2>/dev/null || true

if network_snapshot_rollback_test; then
    pass "network snapshot latest-write rollback"
else
    fail "network snapshot latest-write rollback"
fi


printf "%s\n" "" "=== CLI DISPATCH ==="

if ./feature.sh run network json >/dev/null 2>&1; then
    pass "feature CLI network dispatch"
else
    fail "feature CLI network dispatch"
fi

if ./nht features run network json >/dev/null 2>&1; then
    pass "nht network dispatch"
else
    fail "nht network dispatch"
fi

printf "%s\n" "" "=== SUMMARY ==="

printf "Passed : %s\n" "$PASS"
printf "Failed : %s\n" "$FAIL"

if [ "$FAIL" -eq 0 ]; then
    printf "%s\n" "NETWORK QUALIFICATION: GREEN"
    exit 0
fi

printf "%s\n" "NETWORK QUALIFICATION: RED" >&2
exit 1
