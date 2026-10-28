#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Intelligence / Scan Feature
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/network/scan.sh"
source "$SCRIPT_DIR/lib/network/tools.sh"
source "$SCRIPT_DIR/lib/network/profiles.sh"
source "$SCRIPT_DIR/lib/network/report.sh"
source "$SCRIPT_DIR/lib/network/data.sh"

# Project-owned runtime persistence.
# Keep snapshot paths anchored to the Toolkit tree even when nht
# is launched from another working directory.
NHT_RUNTIME_DIR="${NHT_RUNTIME_DIR:-$SCRIPT_DIR/runtime}"
source "$SCRIPT_DIR/lib/network/snapshot.sh"
network_report_current() {
    local iface=""
    local gateway=""
    local ipv4=""
    local network=""

    if declare -F scan_detect_interface >/dev/null 2>&1; then
        iface="$(scan_detect_interface)"
    fi

    if declare -F scan_detect_gateway >/dev/null 2>&1; then
        gateway="$(scan_detect_gateway)"
    fi

    if [[ -n "$iface" ]] &&
       declare -F scan_detect_ipv4 >/dev/null 2>&1; then
        ipv4="$(scan_detect_ipv4 "$iface" 2>/dev/null || true)"
    fi

    if declare -F scan_private_network >/dev/null 2>&1; then
        network="$(
            scan_private_network "${ipv4%%/*}" 2>/dev/null || true
        )"
    fi

    network_report \
        "${iface:-unknown}" \
        "${ipv4:-unknown}" \
        "${gateway:-unknown}" \
        "${network:-unknown}"
}



network_data_current() {
    local iface=""
    local gateway=""
    local ipv4=""
    local network=""

    if declare -F scan_detect_interface >/dev/null 2>&1; then
        iface="$(scan_detect_interface)"
    fi

    if declare -F scan_detect_gateway >/dev/null 2>&1; then
        gateway="$(scan_detect_gateway)"
    fi

    if [[ -n "$iface" ]] &&
       declare -F scan_detect_ipv4 >/dev/null 2>&1; then
        ipv4="$(scan_detect_ipv4 "$iface" 2>/dev/null || true)"
    fi

    if declare -F scan_private_network >/dev/null 2>&1; then
        network="$(
            scan_private_network "${ipv4%%/*}" 2>/dev/null || true
        )"
    fi

    network_data_json         "${iface:-unknown}"         "${ipv4:-unknown}"         "${gateway:-unknown}"         "${network:-unknown}"
}



case "${1:-intelligence}" in

    intelligence)
        network_intelligence
        ;;

    scan)
        network_scan
        ;;

    quick)
        network_profile quick
        ;;

    standard)
        network_profile standard
        ;;

    diagnostic)
        network_profile diagnostic
        ;;

    tools)
        network_profile tools
        ;;

    report)
        network_report_current
        ;;

    json)
        network_data_current
        ;;

    snapshot)
        snapshot_json="$(network_data_current)" || exit 1

        if ! snapshot_path="$(network_snapshot_save "$snapshot_json")"; then
            echo "[✗] Failed to save network snapshot." >&2
            exit 1
        fi

        echo "$snapshot_path"
        ;;

    snapshots)
        network_snapshot_list
        ;;

    latest)
        if ! network_snapshot_latest; then
            echo "[✗] No network snapshot available." >&2
            exit 1
        fi
        ;;

    validate)
        snapshot_file="${2:-}"

        if [[ -z "$snapshot_file" ]]; then
            echo "[✗] Snapshot file required." >&2
            exit 1
        fi

        if [[ ! -f "$snapshot_file" ]]; then
            echo "[✗] Snapshot file not found: $snapshot_file" >&2
            exit 1
        fi

        snapshot_json="$(cat "$snapshot_file" 2>/dev/null)" || {
            echo "[✗] Failed to read snapshot file." >&2
            exit 1
        }

        if ! network_snapshot_validate "$snapshot_json"; then
            echo "[✗] Invalid network snapshot: $snapshot_file" >&2
            exit 1
        fi

        echo "[✓] Valid network snapshot: $snapshot_file"
        ;;

    *)
        echo "[✗] Unknown network action: $1"
        echo
        echo "Available:"
        echo "  intelligence"
        echo "  scan"
        echo "  quick"
        echo "  standard"
        echo "  diagnostic"
        echo "  tools"
        echo "  report"
        echo "  json"
        echo "  snapshot"
        echo "  snapshots"
        echo "  latest"
        echo "  validate <snapshot>"
        exit 1
        ;;

esac
