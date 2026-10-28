#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Tool Capability Engine
###############################################################################

NETWORK_TOOLS_VERSION="0.1"

network_tool_exists() {
    command -v "$1" >/dev/null 2>&1
}

network_tool_path() {
    command -v "$1" 2>/dev/null || true
}

network_tool_status() {
    local tool="$1"

    if network_tool_exists "$tool"; then
        printf '[✓] %-12s %s\n' "$tool" "$(network_tool_path "$tool")"
    else
        printf '[ ] %-12s unavailable\n' "$tool"
    fi
}

network_tools_report() {
    echo
    echo "============================================"
    echo " NETWORK TOOL CAPABILITIES"
    echo "============================================"
    echo
    echo "Engine : $NETWORK_TOOLS_VERSION"
    echo

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
        network_tool_status "$tool"
    done
}

network_has_termux_wifi() {
    command -v termux-wifi-connectioninfo >/dev/null 2>&1
}

network_has_termux_api() {
    command -v termux-battery-status >/dev/null 2>&1 ||
    command -v termux-wifi-connectioninfo >/dev/null 2>&1
}

network_capability_summary() {
    local available=0
    local total=0
    local tool

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

    for tool in "${tools[@]}"; do
        ((total++))

        if network_tool_exists "$tool"; then
            ((available++))
        fi
    done

    echo "Available tools : $available"
    echo "Known tools     : $total"

    if network_has_termux_wifi; then
        echo "Termux Wi-Fi API: available"
    else
        echo "Termux Wi-Fi API: unavailable"
    fi
}
