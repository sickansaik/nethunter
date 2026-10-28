#!/usr/bin/env bash

# One source inventory for backup, restore and update. Generated network data
# lives inside runtime and is included in installation backups.
NHT_INSTALL_ITEMS=(
    config lib modules runtime install.sh repair.sh update.sh backup.sh
    restore.sh status.sh toolkit.sh cleanup.sh nht doctor.sh feature.sh
)
NHT_RELEASE_METADATA=(release.manifest RELEASE_INFO RELEASE-QUALIFICATION.md README.md)
NHT_REQUIRED_FILES=(
    config/version.conf config/settings.conf
    lib/installation.sh lib/colors.sh lib/checks.sh lib/functions.sh lib/logging.sh
    lib/runtime.sh lib/pulse.sh lib/features.sh lib/feature-loader.sh lib/network.sh
    lib/network/data.sh lib/network/profiles.sh lib/network/report.sh
    lib/network/scan.sh lib/network/snapshot.sh lib/network/tools.sh
    modules/01-termux.sh modules/02-ubuntu.sh modules/03-x11.sh modules/04-xfce.sh
    modules/05-security.sh modules/06-devtools.sh modules/07-performance.sh
    modules/09-toolkit-control.sh modules/10-network.sh
    modules/features/system.sh modules/features/runtime.sh
    modules/features/security.sh modules/features/network.sh
    runtime/ubuntu-gui.sh
)

nht_require_installation() {
    local root="$1" item
    [[ -f "$root/lib/installation.sh" ]] || return 1
    for item in config lib modules runtime; do
        [[ -d "$root/$item" && ! -L "$root/$item" ]] || return 1
    done
    for item in "${NHT_INSTALL_ITEMS[@]:4}" "${NHT_REQUIRED_FILES[@]}"; do
        [[ -f "$root/$item" && ! -L "$root/$item" ]] || {
            printf 'Missing installation item: %s\n' "$item" >&2
            return 1
        }
    done
    # Match restore's policy for the whole owned tree, including generated data.
    local unsafe
    unsafe="$(find "$root/config" "$root/lib" "$root/modules" "$root/runtime" \
        ! -type d ! -type f -print -quit)" || return 1
    [[ -z "$unsafe" ]] || { printf 'Unsafe installation item: %s\n' "$unsafe" >&2; return 1; }
}

nht_backup_items() {
    local root="$1" item
    NHT_BACKUP_ITEMS=("${NHT_INSTALL_ITEMS[@]}")
    for item in "${NHT_RELEASE_METADATA[@]}"; do
        [[ ! -f "$root/$item" ]] || NHT_BACKUP_ITEMS+=("$item")
    done
}

# Verify the actual saved bytes with restore's extractor and completeness checks.
# Never replace live files unless the safety backup passes this same policy.
nht_verify_backup() {
    local archive="$1" verify_dir rc=0
    verify_dir="$(mktemp -d "$(dirname "$archive")/.backup-verify.XXXXXX")" || return 1
    if nht_extract_backup "$archive" "$verify_dir" && nht_require_installation "$verify_dir"; then
        rc=0
    else
        rc=1
    fi
    rm -rf -- "$verify_dir" || return 1
    return "$rc"
}

# Validate the entire archive before extraction. Links, special files, duplicate
# paths, traversal and files outside the installation inventory are rejected.
nht_extract_backup() {
    local archive="$1" destination="$2"
    python - "$archive" "$destination" "${NHT_INSTALL_ITEMS[@]}" "${NHT_RELEASE_METADATA[@]}" <<'PY'
import pathlib
import sys
import tarfile

try:
    with tarfile.open(sys.argv[1], "r:gz") as archive:
        members = archive.getmembers()
        seen = set()
        allowed = set(sys.argv[3:])
        for member in members:
            path = pathlib.PurePosixPath(member.name)
            if (path.is_absolute() or ".." in path.parts or not path.parts
                    or path.parts[0] not in allowed or "\\" in member.name
                    or not (member.isfile() or member.isdir())
                    or str(path) in seen):
                raise ValueError("Unsafe archive entry: " + member.name)
            seen.add(str(path))
        archive.extractall(sys.argv[2], members=members)
except (OSError, tarfile.TarError, ValueError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
PY
}
