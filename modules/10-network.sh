#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 10 - Network Engine
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/runtime.sh"

###############################################################################
# Helpers
###############################################################################

network_ok() {
    log_ok "$1"
}

network_warn() {
    log_warn "$1"
}

network_error() {
    log_error "$1"
}

ubuntu_exec() {
    runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "$1"
}

###############################################################################
# Header
###############################################################################

network_header() {
    echo
    echo "============================================"
    echo "        NETHUNTER NETWORK ENGINE"
    echo "============================================"
    echo
}

###############################################################################
# Interfaces
###############################################################################

show_interfaces() {

    network_header
    echo "NETWORK INTERFACES"
    echo "============================================"
    echo

    if ! ubuntu_exec '
        command -v ip >/dev/null 2>&1 &&
        ip -brief addr
    '
    then
        network_error "Kunde inte läsa nätverksinterface."
        return 1
    fi
}

###############################################################################
# Routes
###############################################################################

show_routes() {

    network_header
    echo "ROUTING TABLE"
    echo "============================================"
    echo

    if ! ubuntu_exec '
        command -v ip >/dev/null 2>&1 &&
        ip route
    '
    then
        network_error "Kunde inte läsa routingtabellen."
        return 1
    fi
}

###############################################################################
# DNS
###############################################################################

show_dns() {

    network_header
    echo "DNS CONFIGURATION"
    echo "============================================"
    echo

    echo "--- /etc/resolv.conf ---"

    ubuntu_exec '
        if [[ -r /etc/resolv.conf ]]; then
            cat /etc/resolv.conf
        else
            exit 1
        fi
    ' || {
        network_error "Kunde inte läsa /etc/resolv.conf."
        return 1
    }

    echo
    echo "--- DNS resolution ---"

    if ubuntu_exec '
        getent hosts example.com >/dev/null 2>&1
    '
    then
        network_ok "DNS resolution fungerar."
    else
        network_error "DNS resolution fungerar inte."
        return 1
    fi
}

###############################################################################
# Connectivity
###############################################################################

check_connectivity() {

    network_header
    echo "CONNECTIVITY"
    echo "============================================"
    echo

    local failures=0

    echo -n "IP connectivity : "

    if ubuntu_exec '
        ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1
    '
    then
        echo "OK"
    else
        echo "FAILED"
        ((failures+=1))
    fi

    echo -n "DNS resolution  : "

    if ubuntu_exec '
        getent hosts example.com >/dev/null 2>&1
    '
    then
        echo "OK"
    else
        echo "FAILED"
        ((failures+=1))
    fi

    echo -n "HTTPS            : "

    if ubuntu_exec '
        curl -fsS --connect-timeout 5 \
            https://example.com >/dev/null 2>&1
    '
    then
        echo "OK"
    else
        echo "FAILED"
        ((failures+=1))
    fi

    echo

    if (( failures == 0 )); then
        network_ok "Internet connectivity är frisk."
        return 0
    fi

    network_error "$failures connectivity-test misslyckades."
    return 1
}

###############################################################################
# Listening sockets
###############################################################################

show_sockets() {

    network_header
    echo "LISTENING SOCKETS"
    echo "============================================"
    echo

    if ! ubuntu_exec 'command -v ss >/dev/null 2>&1'; then
        network_error "ss saknas."
        return 1
    fi

    local socket_output
    local socket_rc

    socket_output="$(
        ubuntu_exec 'ss -tuln 2>&1'
    )"
    socket_rc=$?

    if (( socket_rc != 0 )); then
        network_error "Kunde inte läsa socket-tabellen."
        return 1
    fi

    if printf '%s\n' "$socket_output" |
        grep -q 'Cannot open netlink socket: Permission denied'
    then
        echo "[!] Socket process/netlink information begränsad av PRoot."
        echo
        echo "--- Available socket output ---"
        printf '%s\n' "$socket_output" |
            grep -v 'Cannot open netlink socket: Permission denied' || true
        echo
        network_warn "Socket-diagnostik är begränsad i rootless PRoot."
        return 0
    fi

    printf '%s\n' "$socket_output"
    return 0
}

###############################################################################
# Toolchain
###############################################################################

show_tools() {

    network_header
    echo "NETWORK TOOLCHAIN"
    echo "============================================"
    echo

    local failures=0

    for cmd in ip ss route hostname getent dig nslookup ping curl wget nmap
    do
        if ubuntu_exec "command -v '$cmd' >/dev/null 2>&1"; then
            printf "[✓] %-12s %s\n" \
                "$cmd" \
                "$(ubuntu_exec "command -v '$cmd'")"
        else
            printf "[!] %-12s NOT INSTALLED\n" "$cmd"
            ((failures+=1))
        fi
    done

    echo

    if (( failures == 0 )); then
        network_ok "Network toolchain komplett."
        return 0
    fi

    network_warn "$failures networkverktyg saknas."
    return 1
}

###############################################################################
# Full status
###############################################################################

network_status() {

    network_header

    echo "NETWORK STATUS"
    echo "============================================"
    echo

    echo "--- Interfaces ---"
    ubuntu_exec 'ip -brief addr' || true

    echo
    echo "--- Routes ---"
    ubuntu_exec 'ip route' || true

    echo
    echo "--- DNS ---"
    ubuntu_exec 'cat /etc/resolv.conf 2>/dev/null' || true

    echo
    echo "--- Connectivity ---"

    local failures=0

    if ubuntu_exec 'ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1'; then
        network_ok "IP connectivity"
    else
        network_error "IP connectivity"
        ((failures+=1))
    fi

    if ubuntu_exec 'getent hosts example.com >/dev/null 2>&1'; then
        network_ok "DNS resolution"
    else
        network_error "DNS resolution"
        ((failures+=1))
    fi

    if ubuntu_exec 'curl -fsS --connect-timeout 5 https://example.com >/dev/null 2>&1'; then
        network_ok "HTTPS connectivity"
    else
        network_error "HTTPS connectivity"
        ((failures+=1))
    fi

    echo
    echo "--- Listening sockets ---"

    if ! ubuntu_exec 'command -v ss >/dev/null 2>&1'; then
        network_warn "ss saknas; socket-diagnostik hoppades över."
    else
        local socket_output

        socket_output="$(
            ubuntu_exec 'ss -tuln 2>&1'
        )"

        if printf '%s\n' "$socket_output" |
            grep -q 'Cannot open netlink socket: Permission denied'
        then
            echo "[!] Socket process/netlink information begränsad av PRoot."
            printf '%s\n' "$socket_output" |
                grep -v 'Cannot open netlink socket: Permission denied' || true
            network_warn "Socket-diagnostik är begränsad i rootless PRoot."
        else
            printf '%s\n' "$socket_output"
        fi
    fi

    echo

    if (( failures == 0 )); then
        network_ok "Network status: HEALTHY"
        return 0
    fi

    network_error "Network status: ATTENTION REQUIRED"
    return 1
}

###############################################################################
# Main
###############################################################################

COMMAND="${1:-status}"

case "$COMMAND" in

    status)
        network_status
        ;;

    interfaces)
        show_interfaces
        ;;

    route|routes)
        show_routes
        ;;

    dns)
        show_dns
        ;;

    connectivity|connect)
        check_connectivity
        ;;

    sockets)
        show_sockets
        ;;

    tools)
        show_tools
        ;;

    *)
        echo
        echo "Usage:"
        echo "  10-network.sh status"
        echo "  10-network.sh interfaces"
        echo "  10-network.sh route"
        echo "  10-network.sh dns"
        echo "  10-network.sh connectivity"
        echo "  10-network.sh sockets"
        echo "  10-network.sh tools"
        echo
        exit 1
        ;;

esac
