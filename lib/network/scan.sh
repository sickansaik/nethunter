#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Scan Engine
#
# Scope:
#   - Local-network discovery only
#   - Read-only diagnostics
#   - No configuration changes
#   - No destructive operations
###############################################################################

NETWORK_SCAN_VERSION="0.1"

scan_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

scan_section() {
    echo
    echo "============================================"
    echo " $1"
    echo "============================================"
}

scan_detect_interface() {
    local iface=""

    if scan_command_exists ip; then
        iface="$(
            ip route 2>/dev/null |
            awk '$1 == "default" {print $5; exit}'
        )"
    fi

    if [[ -z "$iface" && -r /proc/net/route ]]; then
        iface="$(
            awk '
                NR > 1 && $2 == "00000000" {
                    print $1
                    exit
                }
            ' /proc/net/route
        )"
    fi

    echo "$iface"
}

scan_detect_gateway() {
    local gateway=""

    if scan_command_exists ip; then
        gateway="$(
            ip route 2>/dev/null |
            awk '$1 == "default" {print $3; exit}'
        )"
    fi

    if [[ -z "$gateway" && -r /proc/net/route ]]; then
        gateway="$(
            awk '
                NR > 1 && $2 == "00000000" {
                    hex=$3
                    printf "%d.%d.%d.%d\n",
                        strtonum("0x" substr(hex,7,2)),
                        strtonum("0x" substr(hex,5,2)),
                        strtonum("0x" substr(hex,3,2)),
                        strtonum("0x" substr(hex,1,2))
                    exit
                }
            ' /proc/net/route 2>/dev/null
        )"
    fi

    echo "$gateway"
}

scan_detect_ipv4() {
    local iface="$1"
    local address=""

    if [[ -z "$iface" ]]; then
        return 1
    fi

    if scan_command_exists ip; then
        address="$(
            ip -4 addr show dev "$iface" 2>/dev/null |
            awk '/inet / {print $2; exit}'
        )"
    fi

    echo "$address"
}

scan_private_network() {
    local address="$1"

    case "$address" in
        10.*)
            echo "10.0.0.0/8"
            ;;
        192.168.*)
            echo "192.168.0.0/16"
            ;;
        172.16.*|172.17.*|172.18.*|172.19.*|172.20.*|172.21.*|172.22.*|172.23.*|172.24.*|172.25.*|172.26.*|172.27.*|172.28.*|172.29.*|172.30.*|172.31.*)
            echo "172.16.0.0/12"
            ;;
        *)
            return 1
            ;;
    esac
}

scan_local_neighbours() {
    scan_section "LOCAL NEIGHBOURS"

    if scan_command_exists ip; then
        ip neigh 2>/dev/null || true
        return 0
    fi

    if [[ -r /proc/net/arp ]]; then
        echo "--- /proc/net/arp ---"
        cat /proc/net/arp
        return 0
    fi

    echo "[!] No neighbour-table interface available."
}

scan_ping_host() {
    local host="$1"

    if ! scan_command_exists ping; then
        return 2
    fi

    if ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

scan_gateway() {
    local gateway="$1"

    scan_section "GATEWAY REACHABILITY"

    if [[ -z "$gateway" ]]; then
        echo "[!] Gateway could not be determined."
        return 1
    fi

    echo "Gateway: $gateway"

    if scan_ping_host "$gateway"; then
        echo "[✓] Gateway reachable."
        return 0
    fi

    echo "[!] Gateway did not respond to ICMP."
    echo "[i] This does not necessarily mean the gateway is offline."
    return 1
}

scan_environment() {
    scan_section "SCAN ENVIRONMENT"

    local iface
    local gateway
    local ipv4
    local network

    iface="$(scan_detect_interface)"
    gateway="$(scan_detect_gateway)"
    ipv4="$(scan_detect_ipv4 "$iface" 2>/dev/null || true)"
    network="$(scan_private_network "${ipv4%%/*}" 2>/dev/null || true)"

    echo "Interface : ${iface:-unknown}"
    echo "IPv4      : ${ipv4:-unknown}"
    echo "Gateway   : ${gateway:-unknown}"
    echo "Network   : ${network:-unknown}"

    if [[ -n "$network" ]]; then
        echo "[✓] Private network detected."
    else
        echo "[!] Local private network could not be derived."
    fi
}

scan_discover() {
    scan_section "DISCOVERY"

    local gateway
    gateway="$(scan_detect_gateway)"

    if [[ -z "$gateway" ]]; then
        echo "[!] Discovery requires a detected gateway."
        return 1
    fi

    echo "Discovery target: local gateway"
    echo

    if scan_ping_host "$gateway"; then
        echo "[✓] $gateway reachable"
    else
        echo "[!] $gateway did not respond"
    fi

    scan_local_neighbours
}

network_scan() {
    echo
    echo "============================================================"
    echo "        NETWORK SCAN"
    echo "============================================================"
    echo
    echo "Engine : $NETWORK_SCAN_VERSION"
    echo "Scope  : Local network discovery"
    echo "Mode   : Read-only"
    echo

    scan_environment

    local gateway
    gateway="$(scan_detect_gateway)"

    scan_gateway "$gateway" || true
    scan_discover || true

    echo
    echo "============================================================"
    echo " NETWORK SCAN COMPLETE"
    echo "============================================================"
}
