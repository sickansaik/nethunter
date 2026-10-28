#!/usr/bin/env bash

set -u

ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
    pwd
)" || exit 1

FAIL=0
CHECKS=0
PASSED=0

pass() {
    CHECKS=$((CHECKS + 1))
    PASSED=$((PASSED + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    CHECKS=$((CHECKS + 1))
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

section() {
    printf '\n=== %s ===\n' "$1"
}

cd "$ROOT" || exit 1

echo
echo "============================================================"
echo " NetHunter Toolkit — Development Check"
echo "============================================================"

section "Repository"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "Git repository"
else
    fail "Git repository"
fi

if [ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$ROOT" ]; then
    pass "repository root"
else
    fail "repository root"
fi

section "Required files"

for file in \
    config/version.conf \
    config/release-anchor.conf \
    install.sh \
    doctor.sh \
    status.sh \
    nht
do
    if [ -f "$file" ]; then
        pass "$file"
    else
        fail "$file"
    fi
done

section "Shell syntax"

shell_count=0
syntax_fail=0

while IFS= read -r file; do
    shell_count=$((shell_count + 1))

    if ! bash -n "$file"; then
        printf 'FAIL: syntax: %s\n' "$file" >&2
        syntax_fail=$((syntax_fail + 1))
    fi
done < <(
    find . \
        -path './.git' -prune -o \
        -path './backups' -prune -o \
            -path './.dev-tools' -prune -o \
        -type f \
        -name '*.sh' \
        -print |
    sort
)

if [ "$syntax_fail" -eq 0 ]; then
    pass "shell syntax ($shell_count files)"
else
    fail "shell syntax ($syntax_fail/$shell_count failed)"
fi

section "ShellCheck"

if ! command -v shellcheck >/dev/null 2>&1; then
    fail "shellcheck available"
else
    shellcheck_files=()

    while IFS= read -r file; do
        shellcheck_files+=("$file")
    done < <(
        find . \
            -path './.git' -prune -o \
            -path './backups' -prune -o \
            -path './.dev-tools' -prune -o \
            -type f \
            -name '*.sh' \
            -print |
        sort
    )

    if shellcheck --severity=warning "${shellcheck_files[@]}"; then
        pass "ShellCheck (${#shellcheck_files[@]} files)"
    else
        fail "ShellCheck (${#shellcheck_files[@]} files)"
    fi
fi

section "Generated-state hygiene"

generated_tracked="$(
    git ls-files |
    grep -E \
        '^(backups/|logs/|runtime/network/latest\.json$|runtime/network/snapshots/)' \
        || true
)"

if [ -z "$generated_tracked" ]; then
    pass "generated state excluded from Git"
else
    fail "generated state tracked by Git"
    printf '%s\n' "$generated_tracked" >&2
fi

section "Release anchor"

if grep -Fxq \
    'RELEASE_VERSION="0.5.0"' \
    config/release-anchor.conf 2>/dev/null
then
    pass "certified release version anchor"
else
    fail "certified release version anchor"
fi

if grep -Fxq \
    'CERTIFIED_ARCHIVE_SHA256="90f07fa3d48564516b1c3c4d1f46d8f5076b8f2da512156fa4f43a9426ce6635"' \
    config/release-anchor.conf 2>/dev/null
then
    pass "certified archive identity"
else
    fail "certified archive identity"
fi

section "Summary"

echo "Checks : $CHECKS"
echo "Passed : $PASSED"
echo "Failed : $FAIL"

echo
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo " DEVELOPMENT CHECK: GREEN"
    echo "============================================================"
    exit 0
fi

echo " DEVELOPMENT CHECK: RED"
echo "============================================================"
exit 1
