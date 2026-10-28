#!/usr/bin/env bash

set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf '%s\n' 'REGRESSION: RED — not a Git repository' >&2
    exit 1
}

cd "$ROOT" || exit 1

PASS=0
FAIL=0

pass() {
    printf 'PASS: %s\n' "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAIL=$((FAIL + 1))
}

printf '%s\n' \
    '============================================================' \
    '        NetHunter Toolkit — Regression Gate' \
    '============================================================' \
    ''

printf '%s\n' '=== SOURCE CONTRACT ==='

for file in \
    lib/runtime.sh \
    modules/09-toolkit-control.sh \
    modules/10-network.sh \
    doctor.sh
do
    if [[ -f "$file" ]]; then
        pass "required source: $file"
    else
        fail "missing source: $file"
    fi
done

printf '%s\n' '' '=== RUNTIME CONTRACT ==='

runtime_symbols=(
    runtime_ubuntu_login
    runtime_ubuntu_ready
    runtime_x11_running
    runtime_x11_test
    runtime_ubuntu_x11_test
    runtime_xfce_running
    runtime_gui_ready
)

for symbol in "${runtime_symbols[@]}"; do
    if bash -c '
        source lib/runtime.sh
        declare -F "$1" >/dev/null 2>&1
    ' bash "$symbol"; then
        pass "runtime function: $symbol"
    else
        fail "missing runtime function: $symbol"
    fi
done

printf '%s\n' '' '=== CONTROL CONTRACT ==='

control_symbols=(
    control_runtime_check
    security_gate
    network_gate
)

for symbol in "${control_symbols[@]}"; do
    if grep -Eq "^${symbol}[[:space:]]*\\(\\)" modules/09-toolkit-control.sh; then
        pass "control function: $symbol"
    else
        fail "missing control function: $symbol"
    fi
done

printf '%s\n' '' '=== NETWORK CONTRACT ==='

if grep -Eq '^network_intelligence[[:space:]]*\(\)' lib/network.sh; then
    pass 'network intelligence entrypoint'
else
    fail 'network intelligence entrypoint'
fi

printf '%s\n' '' '=== SYNTAX ==='

for file in \
    lib/runtime.sh \
    modules/09-toolkit-control.sh \
    modules/10-network.sh \
    doctor.sh \
    lib/network.sh
do
    if bash -n "$file"; then
        pass "syntax: $file"
    else
        fail "syntax: $file"
    fi
done

printf '%s\n' '' '=== LIVE DOCTOR ==='

if ./doctor.sh >/dev/null 2>&1; then
    pass 'doctor'
else
    fail 'doctor'
fi

printf '%s\n' '' '=== LIVE CONTROL ==='

if modules/09-toolkit-control.sh check >/dev/null 2>&1; then
    pass 'toolkit control runtime'
else
    fail 'toolkit control runtime'
fi

printf '%s\n' '' '=== LIVE NETWORK ==='

if modules/10-network.sh status >/dev/null 2>&1; then
    pass 'network status'
else
    fail 'network status'
fi

printf '%s\n' '' '=== SUMMARY ==='

printf 'Passed : %s\n' "$PASS"
printf 'Failed : %s\n' "$FAIL"

if [ "$FAIL" -eq 0 ]; then
    printf '%s\n' 'REGRESSION: GREEN'
    exit 0
fi

printf '%s\n' 'REGRESSION: RED' >&2
exit 1
