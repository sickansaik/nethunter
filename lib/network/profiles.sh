#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Scan Profiles
###############################################################################

profile_section() {
    echo
    echo "============================================"
    echo " $1"
    echo "============================================"
}

network_profile_quick() {
    profile_section "QUICK NETWORK PROFILE"

    echo
    echo "Mode: local / read-only"
    echo

    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
            echo "[✓] Internet IPv4 reachability: available"
        else
            echo "[!] Internet IPv4 reachability: unavailable"
        fi
    else
        echo "[!] ping unavailable."
    fi

    if command -v ip >/dev/null 2>&1; then
        echo
        echo "--- Interfaces ---"
        ip -brief addr 2>/dev/null || ip addr 2>/dev/null
    elif [[ -r /proc/net/dev ]]; then
        echo
        echo "--- Interfaces (/proc/net/dev) ---"
        awk 'NR > 2 {print $1}' /proc/net/dev |
            sed 's/://'
    else
        echo "[!] Interface information unavailable."
    fi

    echo
    echo "--- Neighbours ---"

    if command -v ip >/dev/null 2>&1; then
        ip neigh 2>/dev/null || true
    elif [[ -r /proc/net/arp ]]; then
        cat /proc/net/arp
    else
        echo "[!] Neighbour information unavailable."
    fi
}

network_profile_standard() {
    profile_section "STANDARD NETWORK PROFILE"

    echo
    echo "Mode: local / read-only"
    echo

    if command -v ip >/dev/null 2>&1; then
        echo "--- Addresses ---"
        ip -brief addr 2>/dev/null || ip addr 2>/dev/null

        echo
        echo "--- Routes ---"
        ip route 2>/dev/null || true

        echo
        echo "--- Neighbours ---"
        ip neigh 2>/dev/null || true

        echo
        echo "--- IPv6 ---"
        ip -6 addr 2>/dev/null || true

    else
        echo "[!] ip unavailable."
        echo "[i] Falling back to procfs."

        if [[ -r /proc/net/dev ]]; then
            echo
            echo "--- Interfaces ---"
            awk 'NR > 2 {print $1}' /proc/net/dev |
                sed 's/://'
        fi

        if [[ -r /proc/net/route ]]; then
            echo
            echo "--- Routes ---"
            cat /proc/net/route
        fi

        if [[ -r /proc/net/arp ]]; then
            echo
            echo "--- ARP ---"
            cat /proc/net/arp
        fi
    fi

    echo
    echo "--- DNS ---"

    if [[ -r "$PREFIX/etc/resolv.conf" ]]; then
        grep -E '^[[:space:]]*nameserver[[:space:]]+' \
            "$PREFIX/etc/resolv.conf" 2>/dev/null || true
    elif [[ -r /etc/resolv.conf ]]; then
        grep -E '^[[:space:]]*nameserver[[:space:]]+' \
            /etc/resolv.conf 2>/dev/null || true
    else
        echo "[!] DNS configuration unavailable."
    fi
}

network_profile_diagnostic() {
    profile_section "NETWORK DIAGNOSTIC PROFILE"

    echo
    echo "Mode: diagnostic / read-only"
    echo

    echo "--- IPv4 connectivity ---"

    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            echo "[✓] 1.1.1.1 reachable"
        else
            echo "[!] 1.1.1.1 unreachable"
        fi
    else
        echo "[!] ping unavailable."
    fi

    echo
    echo "--- DNS resolution ---"

    if command -v getent >/dev/null 2>&1; then
        if getent hosts example.com >/dev/null 2>&1; then
            echo "[✓] DNS resolution operational"
        else
            echo "[!] DNS resolution failed"
        fi
    elif command -v nslookup >/dev/null 2>&1; then
        if nslookup example.com >/dev/null 2>&1; then
            echo "[✓] DNS resolution operational"
        else
            echo "[!] DNS resolution failed"
        fi
    elif command -v dig >/dev/null 2>&1; then
        if dig +short example.com >/dev/null 2>&1; then
            echo "[✓] DNS resolver available"
        else
            echo "[!] DNS query failed"
        fi
    else
        echo "[!] No DNS query utility available."
    fi

    echo
    echo "--- HTTPS connectivity ---"

    if command -v curl >/dev/null 2>&1; then
        if curl -Is --connect-timeout 3 https://example.com >/dev/null 2>&1; then
            echo "[✓] HTTPS connectivity operational"
        else
            echo "[!] HTTPS connectivity failed"
        fi
    else
        echo "[!] curl unavailable."
    fi

    echo
    echo "--- Socket information ---"

    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null || true
    elif [[ -r /proc/net/tcp ]]; then
        echo "[i] ss unavailable; procfs socket information:"
        cat /proc/net/tcp
    else
        echo "[!] Socket information unavailable."
    fi
}

network_profile_tools() {
    profile_section "NETWORK TOOL PROFILE"

    echo
    echo "Mode: capability inspection"
    echo

    if declare -F network_tools_report >/dev/null 2>&1; then
        network_tools_report
    else
        echo "[✗] Capability engine not loaded."
        return 1
    fi

    echo
    network_capability_summary
}

network_profile() {
    local profile="${1:-quick}"

    case "$profile" in
        quick)
            network_profile_quick
            ;;
        standard)
            network_profile_standard
            ;;
        diagnostic)
            network_profile_diagnostic
            ;;
        tools)
            network_profile_tools
            ;;
        *)
            echo "[✗] Unknown network profile: $profile"
            echo
            echo "Available profiles:"
            echo "  quick"
            echo "  standard"
            echo "  diagnostic"
            echo "  tools"
            return 1
            ;;
    esac
}
