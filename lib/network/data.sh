#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Evolution
# Network Data Model
#
# Purpose:
#   Produce machine-readable network information.
#
# Scope:
#   - Read-only
#   - Local diagnostics
#   - No configuration changes
#   - No destructive operations
###############################################################################

NETWORK_DATA_VERSION="0.1"

network_data_escape_json() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"

    printf '%s' "$value"
}

network_data_interface() {
    local iface="${1:-unknown}"
    local ipv4="${2:-unknown}"

    printf '{'
    printf '"name":"%s",' \
        "$(network_data_escape_json "$iface")"
    printf '"ipv4":"%s"' \
        "$(network_data_escape_json "$ipv4")"
    printf '}'
}

network_data_json() {
    local iface="${1:-unknown}"
    local ipv4="${2:-unknown}"
    local gateway="${3:-unknown}"
    local network="${4:-unknown}"

    local ipv6="false"
    local internet="false"

    if command -v ip >/dev/null 2>&1; then
        if ip -6 addr 2>/dev/null | grep -q 'inet6'; then
            ipv6="true"
        fi
    fi

    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            internet="true"
        fi
    fi

    printf '{'
    printf '"schema":"nht.network.v1",'
    printf '"engine":"%s",' \
        "$(network_data_escape_json "$NETWORK_DATA_VERSION")"
    printf '"mode":"read-only",'
    printf '"scope":"local-network-diagnostics",'

    printf '"environment":{'
    printf '"interface":"%s",' \
        "$(network_data_escape_json "$iface")"
    printf '"ipv4":"%s",' \
        "$(network_data_escape_json "$ipv4")"
    printf '"gateway":"%s",' \
        "$(network_data_escape_json "$gateway")"
    printf '"network":"%s"' \
        "$(network_data_escape_json "$network")"
    printf '},'

    printf '"connectivity":{'
    printf '"ipv4_internet":%s' "$internet"
    printf '},'

    printf '"ipv6":{'
    printf '"detected":%s' "$ipv6"
    printf '},'

    printf '"tools":['

    local first=1
    local tool

    for tool in \
        ip \
        ping \
        ss \
        curl \
        wget \
        dig \
        nslookup \
        traceroute \
        tcpdump \
        nmap \
        iw \
        arp
    do
        if command -v "$tool" >/dev/null 2>&1; then
            if (( first == 0 )); then
                printf ','
            fi

            printf '"%s"' \
                "$(network_data_escape_json "$tool")"

            first=0
        fi
    done

    printf ']'
    printf '}'
    printf '\n'
}

network_data_validate_json() {
    local data="$1"

    if command -v python >/dev/null 2>&1; then
        printf '%s\n' "$data" |
            python -m json.tool >/dev/null 2>&1
        return $?
    fi

    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$data" |
            jq empty >/dev/null 2>&1
        return $?
    fi

    echo "[!] No JSON validator available."
    return 2
}
