#!/usr/bin/env bash

set -u

usage() {
    printf '%s\n' \
        'Usage: tools/codex-workflow.sh --scope PATH [PATH ...]' \
        '' \
        'Run the mandatory development verification workflow for a declared scope.'
    return 1
}

if [ "$#" -lt 2 ] || [ "$1" != "--scope" ]; then
    usage
    exit 1
fi

shift

if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

scope=()

while [ "$#" -gt 0 ]; do
    scope+=("$1")
    shift
done

review_scope="${scope[*]}"

printf '%s\n' \
    '============================================================' \
    '        NetHunter Toolkit — Codex Workflow' \
    '============================================================' \
    ''

printf '%s\n' '=== CHANGE SCOPE ==='
printf 'Scope: %s\n' "$review_scope"

printf '%s\n' '' '=== SCOPE REVIEW ==='
if ! ./tools/review.sh --scope "${scope[@]}"; then
    printf '%s\n' 'CODEX WORKFLOW: RED — scope review failed' >&2
    exit 1
fi

printf '%s\n' '' '=== SYNTAX ==='
if ! make syntax; then
    printf '%s\n' 'CODEX WORKFLOW: RED — syntax failed' >&2
    exit 1
fi

printf '%s\n' '' '=== LINT ==='
if ! make lint; then
    printf '%s\n' 'CODEX WORKFLOW: RED — lint failed' >&2
    exit 1
fi

printf '%s\n' '' '=== REGRESSION ==='
if ! make regression; then
    printf '%s\n' 'CODEX WORKFLOW: RED — regression failed' >&2
    exit 1
fi

printf '%s\n' '' '=== COMPLETE CHECK ==='
if ! make check; then
    printf '%s\n' 'CODEX WORKFLOW: RED — complete check failed' >&2
    exit 1
fi

printf '%s\n' \
    '' \
    'CODEX WORKFLOW: GREEN' \
    'No commit was created.'
