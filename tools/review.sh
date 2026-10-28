#!/usr/bin/env bash

set -u

usage() {
    printf '%s\n' \
        'Usage: tools/review.sh --scope PATH [PATH ...]' \
        '' \
        'Validate the current Git worktree against an explicit change scope.'
    return 1
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
}

pass() {
    printf 'PASS: %s\n' "$1"
}

if [ "$#" -lt 2 ] || [ "$1" != "--scope" ]; then
    usage
    exit 1
fi

shift

scope=()
while [ "$#" -gt 0 ]; do
    scope+=("$1")
    shift
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    fail "not a Git repository"
    exit 1
}

cd "$ROOT" || exit 1

changed=()
while IFS= read -r line; do
    [ -n "$line" ] || continue

    path="${line:3}"

    if [[ "$path" == *" -> "* ]]; then
        old_path="${path%% -> *}"
        new_path="${path##* -> *}"
        changed+=("$old_path")
        changed+=("$new_path")
    else
        changed+=("$path")
    fi
done < <(
    git status --porcelain=v1 --untracked-files=all
)

if [ "${#changed[@]}" -gt 0 ]; then
    mapfile -t changed < <(printf '%s\n' "${changed[@]}" | sort -u)
fi


if [ "${#changed[@]}" -eq 0 ]; then
    pass "worktree has no changes"
    exit 0
fi

for file in "${changed[@]}"; do
    case "$file" in
        backups/*|logs/*|updates/*|runtime/network/*|config/release-anchor.conf)
            fail "protected path changed: $file"
            exit 1
            ;;
    esac

    if [ "$file" = "release.manifest" ]; then
        fail "release.manifest requires an explicit release change"
        exit 1
    fi

    allowed=0

    for base in "${scope[@]}"; do
        case "$file" in
            "$base"|"$base"/*)
                allowed=1
                break
                ;;
        esac
    done

    if [ "$allowed" -eq 0 ]; then
        fail "scope mismatch: $file"
        exit 1
    fi
done

printf 'Changed files : %s\n' "${#changed[@]}"
printf 'Scope paths   : %s\n' "${#scope[@]}"

for file in "${changed[@]}"; do
    printf '  [✓] %s\n' "$file"
done

pass "change scope"
exit 0
