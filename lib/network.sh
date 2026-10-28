#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Intelligence Engine
###############################################################################

NETWORK_ENGINE_VERSION="0.1"

network_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

network_section() {
    echo
    echo "============================================"
    echo " $1"
    echo "============================================"
}

network_interfaces() {
    network_section "INTERFACES"

    if network_command_exists ip; then
        ip -brief addr 2>/dev/null || ip addr 2>/dev/null
    else
        echo "[!] ip command unavailable."
    fi
}

network_routes() {
    network_section "ROUTING"

    if network_command_exists ip; then
        ip route 2>/dev/null || true
    else
        echo "[!] ip command unavailable."
    fi
}

network_neighbours() {
    network_section "NEIGHBOURS"

    if network_command_exists ip; then
        ip neigh 2>/dev/null || true
    else
        echo "[!] ip command unavailable."
    fi
}

network_dns() {
    network_section "DNS"

    local found=0

    if [[ -f /etc/resolv.conf ]]; then
        echo "--- /etc/resolv.conf ---"
        grep -E '^[[:space:]]*nameserver[[:space:]]+' \
            /etc/resolv.conf 2>/dev/null || true
        found=1
    fi

    if [[ -f "$PREFIX/etc/resolv.conf" ]]; then
        echo "--- Termux resolv.conf ---"
        grep -E '^[[:space:]]*nameserver[[:space:]]+' \
            "$PREFIX/etc/resolv.conf" 2>/dev/null || true
        found=1
    fi

    if (( found == 0 )); then
        echo "[!] DNS configuration could not be located."
    fi
}

network_default_gateway() {
    network_section "DEFAULT GATEWAY"

    if network_command_exists ip; then
        local gateway

        gateway="$(
            ip route 2>/dev/null |
            awk '$1 == "default" {print $3; exit}'
        )"

        if [[ -n "$gateway" ]]; then
            echo "Gateway: $gateway"
        else
            echo "[!] No default gateway detected."
        fi
    else
        echo "[!] ip command unavailable."
    fi
}

network_connectivity() {
    network_section "CONNECTIVITY"

    if network_command_exists ping; then

        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            echo "[✓] IPv4 connectivity: reachable"
        else
            echo "[!] IPv4 connectivity: unavailable"
        fi

    else
        echo "[!] ping command unavailable."
    fi

    if network_command_exists getent; then

        if getent hosts example.com >/dev/null 2>&1; then
            echo "[✓] DNS resolution: operational"
        else
            echo "[!] DNS resolution: failed"
        fi

    elif network_command_exists nslookup; then

        if nslookup example.com >/dev/null 2>&1; then
            echo "[✓] DNS resolution: operational"
        else
            echo "[!] DNS resolution: failed"
        fi

    else
        echo "[!] No DNS resolver utility available."
    fi
}

network_tools() {
    network_section "AVAILABLE NETWORK TOOLS"

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
    )

    local tool

    for tool in "${tools[@]}"; do
        if network_command_exists "$tool"; then
            printf '[✓] %-12s available\n' "$tool"
        else
            printf '[ ] %-12s unavailable\n' "$tool"
        fi
    done
}

network_wifi() {
    network_section "WI-FI"

    if network_command_exists termux-wifi-connectioninfo; then

        termux-wifi-connectioninfo 2>/dev/null || {
            echo "[!] Wi-Fi information unavailable."
        }

    elif network_command_exists iw; then

        iw dev 2>/dev/null || {
            echo "[!] iw could not query Wi-Fi state."
        }

    else
        echo "[!] Wi-Fi information utility unavailable."
    fi
}

network_ipv6() {
    network_section "IPV6"

    if network_command_exists ip; then

        if ip -6 addr 2>/dev/null | grep -q 'inet6'; then
            echo "[✓] IPv6 addresses detected."
            ip -6 addr 2>/dev/null
        else
            echo "[!] No IPv6 addresses detected."
        fi

    else
        echo "[!] ip command unavailable."
    fi
}

network_summary() {
    network_section "NETWORK SUMMARY"

    local interface_count
    local gateway
    local ipv4_count
    local ipv6_count

    interface_count=0
    ipv4_count=0
    ipv6_count=0

    if network_command_exists ip; then

        interface_count="$(
            ip -o link show 2>/dev/null |
            wc -l |
            tr -d ' '
        )"

        ipv4_count="$(
            ip -4 -o addr show 2>/dev/null |
            wc -l |
            tr -d ' '
        )"

        ipv6_count="$(
            ip -6 -o addr show 2>/dev/null |
            wc -l |
            tr -d ' '
        )"

        gateway="$(
            ip route 2>/dev/null |
            awk '$1 == "default" {print $3; exit}'
        )"

    else
        gateway="unknown"
    fi

    echo "Interfaces : $interface_count"
    echo "IPv4 addrs : $ipv4_count"
    echo "IPv6 addrs : $ipv6_count"
    echo "Gateway    : ${gateway:-none}"
}

network_intelligence() {
    echo
    echo "============================================================"
    echo "        NETWORK INTELLIGENCE"
    echo "============================================================"
    echo
    echo "Engine : $NETWORK_ENGINE_VERSION"
    echo

    network_summary
    network_interfaces
    network_default_gateway
    network_routes
    network_dns
    network_connectivity
    network_neighbours
    network_ipv6
    network_wifi
    network_tools

    echo
    echo "============================================================"
    echo " NETWORK INTELLIGENCE COMPLETE"
    echo "============================================================"
}
