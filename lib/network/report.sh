#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Results / Reporting Engine
#
# Scope:
#   - Read-only
#   - Local diagnostics
#   - No configuration changes
#   - No destructive operations
###############################################################################

NETWORK_REPORT_VERSION="0.1"

network_report_section() {
    echo
    echo "============================================"
    echo " $1"
    echo "============================================"
}

network_report() {
    local iface="${1:-unknown}"
    local ipv4="${2:-unknown}"
    local gateway="${3:-unknown}"
    local network="${4:-unknown}"

    echo
    echo "============================================================"
    echo "        NETWORK REPORT"
    echo "============================================================"
    echo
    echo "Engine : $NETWORK_REPORT_VERSION"
    echo "Mode   : Read-only"
    echo "Scope  : Local network diagnostics"
    echo

    network_report_section "ENVIRONMENT"

    echo "Interface : $iface"
    echo "IPv4      : $ipv4"
    echo "Gateway   : $gateway"
    echo "Network   : $network"

    network_report_section "CONNECTIVITY"

    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            echo "[✓] IPv4 Internet connectivity available."
        else
            echo "[!] IPv4 Internet connectivity unavailable."
        fi
    else
        echo "[!] ping unavailable."
    fi

    network_report_section "DNS"

    if [[ -r "$PREFIX/etc/resolv.conf" ]]; then
        echo "--- Termux DNS ---"
        grep -E '^[[:space:]]*nameserver[[:space:]]+' \
            "$PREFIX/etc/resolv.conf" 2>/dev/null || \
            echo "[!] No nameserver entries found."
    elif [[ -r /etc/resolv.conf ]]; then
        echo "--- System DNS ---"
        grep -E '^[[:space:]]*nameserver[[:space:]]+' \
            /etc/resolv.conf 2>/dev/null || \
            echo "[!] No nameserver entries found."
    else
        echo "[!] DNS configuration unavailable."
    fi

    network_report_section "NEIGHBOURS"

    if command -v ip >/dev/null 2>&1; then
        ip neigh 2>/dev/null || true
    elif [[ -r /proc/net/arp ]]; then
        cat /proc/net/arp
    else
        echo "[!] Neighbour information unavailable."
    fi

    network_report_section "IPV6"

    if command -v ip >/dev/null 2>&1; then
        if ip -6 addr 2>/dev/null | grep -q 'inet6'; then
            echo "[✓] IPv6 addresses detected."
        else
            echo "[!] No IPv6 addresses detected."
        fi
    else
        echo "[!] ip unavailable."
    fi

    network_report_section "AVAILABLE TOOLS"

    local tools=(
        ip
        ping
        ss
        curl
        wget
        dig
        nslookup
        traceroute
        tcpdump
        nmap
        iw
        arp
    )

    local tool

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf '[✓] %-12s available\n' "$tool"
        else
            printf '[ ] %-12s unavailable\n' "$tool"
        fi
    done

    echo
    echo "============================================================"
    echo " NETWORK REPORT COMPLETE"
    echo "============================================================"
}
