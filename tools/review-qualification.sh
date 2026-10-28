#!/usr/bin/env bash

set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf '%s\n' 'REVIEW QUALIFICATION: RED — not a Git repository' >&2
    exit 1
}

REVIEW="$ROOT/tools/review.sh"
TMP_ROOT="${TMPDIR:-/tmp}/nht-review-qualification-$$"
TEST_REPO="$TMP_ROOT/repo"

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

cleanup() {
    rm -rf "$TMP_ROOT"
}

trap cleanup EXIT

mkdir -p "$TEST_REPO/tools" || exit 1
cp "$REVIEW" "$TEST_REPO/tools/review.sh" || exit 1
chmod +x "$TEST_REPO/tools/review.sh" || exit 1

cd "$TEST_REPO" || exit 1

git init -q || exit 1
git config user.name "NetHunter Toolkit Qualification"
git config user.email "qualification@localhost"

printf 'baseline\n' > baseline.txt
git add baseline.txt tools/review.sh
git commit -qm "qualification baseline" || exit 1

printf '%s\n' \
    '============================================================' \
    '        NetHunter Toolkit — Review Qualification' \
    '============================================================' \
    ''

printf '%s\n' '=== CLEAN WORKTREE ==='

if ./tools/review.sh --scope baseline.txt >/dev/null 2>&1; then
    pass "clean worktree"
else
    fail "clean worktree"
fi

printf '%s\n' '' '=== EXACT FILE SCOPE ==='

mkdir -p feature
printf 'new\n' > feature/new-file.txt

if ./tools/review.sh --scope feature/new-file.txt >/dev/null 2>&1; then
    pass "exact untracked file scope"
else
    fail "exact untracked file scope"
fi

printf '%s\n' '' '=== DIRECTORY SCOPE ==='

if ./tools/review.sh --scope feature >/dev/null 2>&1; then
    pass "untracked directory scope"
else
    fail "untracked directory scope"
fi

printf '%s\n' '' '=== WRONG SCOPE ==='

if ./tools/review.sh --scope feature/other-file.txt >/dev/null 2>&1; then
    fail "wrong scope rejected"
else
    pass "wrong scope rejected"
fi

rm -rf feature

printf '%s\n' '' '=== PROTECTED PATH ==='

mkdir -p runtime/network
printf 'protected\n' > runtime/network/probe.txt

if ./tools/review.sh --scope runtime/network/probe.txt >/dev/null 2>&1; then
    fail "protected path rejected"
else
    pass "protected path rejected"
fi

rm -rf runtime/network

printf '%s\n' '' '=== SUMMARY ==='
printf 'Passed : %s\n' "$PASS"
printf 'Failed : %s\n' "$FAIL"

if [ "$FAIL" -eq 0 ]; then
    printf '%s\n' 'REVIEW QUALIFICATION: GREEN'
    exit 0
fi

printf '%s\n' 'REVIEW QUALIFICATION: RED' >&2
exit 1
