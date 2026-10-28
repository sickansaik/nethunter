#!/data/data/com.termux/files/usr/bin/bash
# Read-only device checks, apart from writing the qualification report.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 2
PHASE="${1:-}"
case "$PHASE" in
    preflight|installed|gui) ;;
    *) printf 'Usage: bash tools/termux-qualify.sh preflight|installed|gui\n'; exit 2 ;;
esac
if [[ -z "${PREFIX:-}" ]] || ! command -v getprop >/dev/null 2>&1; then
    printf 'Run this check in Termux on Android, outside Ubuntu.\n' >&2
    exit 2
fi
REPORT_DIR="$ROOT/logs/qualification"
mkdir -p "$REPORT_DIR" || exit 2
REPORT="$REPORT_DIR/$(date '+%Y%m%d-%H%M%S')-$PHASE-$$.log"
exec > >(tee "$REPORT") 2>&1
PASS=0
WARN=0
FAIL=0
check() {
    local label="$1" rc
    shift
    printf '\n--- %s ---\n' "$label"
    "$@"
    rc=$?
    if (( rc == 0 )); then
        printf 'PASS: %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf 'FAIL: %s (exit=%s)\n' "$label" "$rc"
        FAIL=$((FAIL + 1))
    fi
}
warning() { printf 'WARN: %s\n' "$1"; WARN=$((WARN + 1)); }
runtime_check() {
    timeout 90 bash -c 'source "$1/lib/runtime.sh"; shift; "$@"' _ "$ROOT" "$@"
}
printf 'NetHunter Toolkit device qualification\nPhase: %s\nDate: %s\n' "$PHASE" "$(date -Iseconds)"
printf 'Android: %s; SDK: %s; ABI: %s\n' "$(getprop ro.build.version.release)" "$(getprop ro.build.version.sdk)" "$(getprop ro.product.cpu.abi)"
printf 'Termux arch: %s; kernel arch: %s\n' "$(dpkg --print-architecture)" "$(uname -m)"
printf 'Report: %s\n' "$REPORT"
for dependency in bash python timeout proot-distro termux-x11 xdpyinfo tar find sha256sum; do
    check "command: $dependency" command -v "$dependency"
done
sdk="$(getprop ro.build.version.sdk)"
check 'Android 8+ (SDK 26+)' test "${sdk:-0}" -ge 26
[[ "$(dpkg --print-architecture)" == aarch64 ]] || warning 'This architecture has not been qualified; historical target is aarch64.'
case "$ROOT" in
    /storage/*|/sdcard/*) check 'Project must be extracted inside Termux HOME' false ;;
    *) check 'Project directory writable' test -w "$ROOT" ;;
esac
check 'Disk space (review available capacity)' df -h "$ROOT"
check 'Toolkit CLI' bash "$ROOT/nht" version
if [[ "$PHASE" != preflight ]]; then
    check 'Ubuntu login' runtime_check runtime_ubuntu_ready
    check 'Ubuntu identity and required GUI programs' runtime_check runtime_ubuntu_login "${NHT_UBUNTU:-ubuntu}" -- bash -c '
        cat /etc/os-release
        failed=0
        for program in startxfce4 xfce4-session xfwm4 xfce4-panel xfdesktop dbus-launch dbus-run-session xdpyinfo pactl python3 git curl; do
            command -v "$program" || failed=1
        done
        exit "$failed"
    '
    check 'Executable CLI and control scripts' bash -c '
        root="$1"
        for file in nht feature.sh doctor.sh status.sh modules/09-toolkit-control.sh modules/features/network.sh; do
            [[ -x "$root/$file" ]] || exit 1
        done
    ' _ "$ROOT"
fi
if [[ "$PHASE" == gui ]]; then
    printf '\nDisplay configuration: %s\n' "${NHT_X11_DISPLAY:-127.0.0.1:1}"
    check 'Termux to X11' runtime_check runtime_x11_test
    check 'Ubuntu to X11' runtime_check runtime_ubuntu_x11_test
    check 'XFCE session, window manager, panel and desktop' runtime_check runtime_xfce_running
    check 'Ubuntu D-Bus process' runtime_check runtime_ubuntu_dbus_running
    check 'Combined GUI readiness' runtime_check runtime_gui_ready
    check 'PulseAudio host' timeout 15 pactl info
    check 'PulseAudio client from Ubuntu' timeout 90 bash -c '
        source "$1/lib/runtime.sh"
        source "$1/lib/pulse.sh"
        pulse_test_ubuntu
    ' _ "$ROOT"
    printf '\nMANUAL CHECK REQUIRED: desktop visible, windows movable, keyboard and pointer working.\n'
fi
printf '\nSUMMARY phase=%s PASS=%s WARN=%s FAIL=%s\nReport: %s\n' "$PHASE" "$PASS" "$WARN" "$FAIL" "$REPORT"
if (( FAIL > 0 )); then exit 2; fi
if (( WARN > 0 )); then exit 1; fi
exit 0
