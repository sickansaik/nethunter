#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 09 - Toolkit Control Layer
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/lib/pulse.sh"
source "$SCRIPT_DIR/lib/runtime.sh"

###############################################################################
# Environment
###############################################################################

DISPLAY_VALUE="$RUNTIME_X11_DISPLAY"
export DISPLAY="$DISPLAY_VALUE"

# Do NOT export an Ubuntu XDG runtime path into the Termux host.
# Ubuntu/PRoot gets its runtime directory inside the individual session.

export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-XFCE}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-xfce}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"

###############################################################################
# Helpers
###############################################################################

control_ok() {
    log_ok "$1"
}

control_warn() {
    log_warn "$1"
}

control_error() {
    log_error "$1"
}

control_info() {
    log_info "$1"
}

###############################################################################
# Runtime state
###############################################################################

control_state() {

    echo
    echo "============================================"
    echo "        TOOLKIT CONTROL STATE"
    echo "============================================"
    echo

    echo "Display           : $DISPLAY"
    echo "XDG_RUNTIME_DIR   : ${XDG_RUNTIME_DIR:-<unset>}"
    echo "Desktop           : $XDG_CURRENT_DESKTOP"
    echo "Session           : $XDG_SESSION_TYPE"
    echo

    if runtime_x11_running; then
        control_ok "Termux:X11 runtime aktiv."
    else
        control_warn "Termux:X11 runtime är inte nåbar."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1; then
        control_ok "Ubuntu PRoot fungerar."
    else
        control_error "Ubuntu PRoot fungerar inte."
        return 1
    fi

    if runtime_ubuntu_x11_test; then
        control_ok "Ubuntu → X11 fungerar."
    else
        control_warn "Ubuntu → X11 fungerar inte."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-session >/dev/null 2>&1'
    then
        control_ok "XFCE session aktiv."
    else
        control_warn "XFCE session är inte aktiv."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfwm4 >/dev/null 2>&1'
    then
        control_ok "XFWM4 aktiv."
    else
        control_warn "XFWM4 är inte aktiv."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfdesktop >/dev/null 2>&1'
    then
        control_ok "XFDesktop aktiv."
    else
        control_warn "XFDesktop är inte aktiv."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-panel >/dev/null 2>&1'
    then
        control_ok "XFCE Panel aktiv."
    else
        control_warn "XFCE Panel är inte aktiv."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c "
        export DISPLAY='$RUNTIME_X11_DISPLAY'
        command -v xfconf-query >/dev/null 2>&1 &&
        xfconf-query -c xsettings -p /Gdk/WindowScalingFactor >/dev/null 2>&1
    "
    then
        control_ok "XFConf fungerar."
    else
        control_warn "XFConf fungerar inte."
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -af "dbus-run-session.*startxfce4" >/dev/null 2>&1'
    then
        control_ok "XFCE D-Bus session aktiv."
    else
        control_warn "XFCE D-Bus session saknas."
    fi

    if pulse_test_host >/dev/null 2>&1; then
        control_ok "Termux PulseAudio fungerar."
    else
        control_warn "Termux PulseAudio kunde inte verifieras."
    fi

    if pulse_test_ubuntu >/dev/null 2>&1; then
        control_ok "Ubuntu → Termux PulseAudio fungerar."
    else
        control_warn "Ubuntu → Termux PulseAudio kunde inte verifieras."
    fi
}

###############################################################################
# Start XFCE
###############################################################################

start_xfce() {

    echo
    echo "============================================"
    echo "START XFCE"
    echo "============================================"
    echo

    if ! runtime_x11_start; then
        control_error "Termux:X11 kunde inte startas eller återställas."
        return 1
    fi

    control_ok "Termux:X11 runtime GREEN."

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-session >/dev/null 2>&1'
    then
        control_ok "XFCE session körs redan."
        return 0
    fi

    # Ensure PulseAudio runtime in Termux.
    pulse_ensure_host || {
        control_error "PulseAudio kunde inte startas."
        return 1
    }

    pulse_prepare_client || {
        control_error "PulseAudio runtime kunde inte förberedas."
        return 1
    }

    local pulse_client_config="$PULSE_CLIENT_CONFIG"
    local pulse_cookie

    pulse_cookie="$(pulse_detect_cookie)" || {
        control_error "PulseAudio-cookie kunde inte hittas."
        return 1
    }

    # IMPORTANT:
    # Keep the PRoot process alive for the entire XFCE session.
    # Do not background startxfce4 inside PRoot because proot-distro
    # uses --kill-on-exit and would terminate the XFCE children.
    local xfce_control_log="$PREFIX/tmp/nht-xfce-control.log"

    # Host-side redirection must use a Termux-writable path.
    : > "$xfce_control_log" || {
        control_error "XFCE-loggen kunde inte skapas: $xfce_control_log"
        return 1
    }

    nohup bash -c 'source "$1"; shift; runtime_ubuntu_login "$@"' _ "$SCRIPT_DIR/lib/runtime.sh" "$RUNTIME_UBUNTU" -- bash -c "
        export DISPLAY='$RUNTIME_X11_DISPLAY'
        export XDG_RUNTIME_DIR='/tmp/runtime-root'
        export XDG_CURRENT_DESKTOP='XFCE'
        export XDG_SESSION_DESKTOP='xfce'
        export XDG_SESSION_TYPE='x11'
        export GDK_BACKEND='x11'
        export XFCE_DISABLE_WM_CHECK=1

        unset PULSE_SERVER
        export PULSE_CLIENTCONFIG='$pulse_client_config'
        export PULSE_COOKIE='$pulse_cookie'

        mkdir -p \"\$XDG_RUNTIME_DIR\"
        chmod 700 \"\$XDG_RUNTIME_DIR\"

        exec dbus-run-session -- startxfce4
    " >"$xfce_control_log" 2>&1 </dev/null &

    sleep 5

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-session >/dev/null 2>&1'
    then
        control_ok "XFCE startad."
        return 0
    fi

    control_error "XFCE kunde inte startas."
    return 1
}

###############################################################################
# Stop XFCE
###############################################################################

stop_xfce() {

    echo
    echo "============================================"
    echo "STOP XFCE"
    echo "============================================"
    echo

    runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c '
        pkill -TERM -x xfce4-panel 2>/dev/null || true
        pkill -TERM -x xfdesktop 2>/dev/null || true
        pkill -TERM -x xfwm4 2>/dev/null || true
        pkill -TERM -x xfce4-session 2>/dev/null || true
    ' >/dev/null 2>&1 || true

    sleep 2

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-session >/dev/null 2>&1'
    then
        control_warn "XFCE session kör fortfarande."
        return 1
    fi

    control_ok "XFCE stoppad."
}


###############################################################################
# Restart XFCE
###############################################################################

restart_xfce() {

    echo
    echo "============================================"
    echo "RESTART XFCE"
    echo "============================================"
    echo

    if ! stop_xfce; then
        control_error "XFCE kunde inte stoppas."
        return 1
    fi

    sleep 1

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-session >/dev/null 2>&1'
    then
        control_error "XFCE session kör fortfarande efter stop."
        return 1
    fi

    control_ok "XFCE stoppad och verifierad."

    if ! start_xfce; then
        control_error "XFCE kunde inte startas efter restart."
        return 1
    fi

    sleep 2

    if control_runtime_check; then
        control_ok "XFCE restart verifierad."
        return 0
    fi

    control_error "XFCE restart startade sessionen men runtime-check misslyckades."
    return 1
}

###############################################################################
# Runtime recovery
###############################################################################

recover_runtime() {

    echo
    echo "============================================"
    echo "        TOOLKIT RUNTIME RECOVERY"
    echo "============================================"
    echo

    control_ok "Startar read-only förstakontroll."

    if control_runtime_check; then
        control_ok "Runtime är redan frisk."
        return 0
    fi

    control_warn "Runtime-check misslyckades. Försöker återställa XFCE."

    control_info "Verifierar och återställer Termux:X11..."

    if ! runtime_x11_start; then
        control_error "Termux:X11 recovery misslyckades."
        return 1
    fi

    control_ok "Termux:X11 runtime GREEN."

    if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1; then
        control_error "Ubuntu PRoot fungerar inte. Recovery avbryts."
        return 1
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'pgrep -x xfce4-session >/dev/null 2>&1'
    then
        control_warn "XFCE session finns men runtime är ofullständig."
        control_info "Försöker starta om XFCE."
        if ! restart_xfce; then
            control_error "XFCE restart misslyckades."
            return 1
        fi
    else
        control_info "XFCE session saknas. Startar XFCE."
        if ! start_xfce; then
            control_error "XFCE kunde inte startas."
            return 1
        fi
    fi

    sleep 2

    if control_runtime_check; then
        control_ok "Runtime recovery lyckades."
        return 0
    fi

    control_error "Runtime recovery misslyckades."
    return 1
}

###############################################################################
# GUI Repair
###############################################################################

control_repair_gui() {

    echo
    echo "============================================"
    echo "        TOOLKIT GUI REPAIR"
    echo "============================================"
    echo

    control_info "Stoppar XFCE innan reparation."

    if ! stop_xfce; then
        control_warn "XFCE kunde inte verifieras som stoppad."
    fi

    sleep 1

    control_info "Kontrollerar Ubuntu GUI-komponenter..."

    if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc '
        export DEBIAN_FRONTEND=noninteractive

        apt-get update &&
        apt-get install -y \
            xfce4-session \
            xfwm4 \
            xfce4-panel \
            xfdesktop4 \
            dbus-x11 \
            x11-utils
    '
    then
        control_error "Ubuntu GUI-komponenterna kunde inte repareras."
        return 1
    fi

    control_ok "Ubuntu GUI-komponenterna är installerade/verifierade."

    control_info "Startar XFCE igen."

    if ! start_xfce; then
        control_error "XFCE kunde inte startas efter GUI-repair."
        return 1
    fi

    sleep 2

    if control_runtime_check; then
        control_ok "GUI repair verifierad. Runtime är GREEN."
        return 0
    fi

    control_error "GUI repair genomfördes men runtime-check misslyckades."
    return 1
}


###############################################################################
# Runtime check
###############################################################################

control_runtime_check() {

    echo
    echo "============================================"
    echo "CONTROL RUNTIME CHECK"
    echo "============================================"
    echo

    if runtime_gui_ready; then
        control_ok "Toolkit runtime är redo."
        return 0
    fi

    control_error "Toolkit runtime är inte redo."

    echo
    control_state

    return 1
}

###############################################################################
# Security gate
###############################################################################

security_gate() {

    echo
    echo "============================================"
    echo "SECURITY TOOL GATE"
    echo "============================================"
    echo

    if ! control_runtime_check; then
        control_error "Security tools blockeras: runtime ej redo."
        return 1
    fi

    if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'command -v nmap >/dev/null 2>&1'
    then
        control_error "nmap saknas."
        return 1
    fi

    control_ok "Security environment redo."
}

###############################################################################
# Network gate
###############################################################################

network_gate() {

    echo
    echo "============================================"
    echo "NETWORK GATE"
    echo "============================================"
    echo

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'dig +short example.com >/dev/null 2>&1'
    then
        control_ok "DNS fungerar."
    else
        control_error "DNS fungerar inte."
        return 1
    fi

    if runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -c \
        'curl -fsS --connect-timeout 5 https://example.com >/dev/null 2>&1'
    then
        control_ok "HTTPS fungerar."
    else
        control_error "HTTPS fungerar inte."
        return 1
    fi

    control_ok "Network environment redo."
}

###############################################################################
# Main
###############################################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    case "${1:-state}" in

        state)
            control_state
            ;;

        check)
            control_runtime_check
            ;;

        start)
            start_xfce
            ;;

        stop)
            stop_xfce
            ;;

        restart)
            restart_xfce
            ;;

        recover)
            recover_runtime
            ;;

        repair)
            control_repair_gui
            ;;

        security)
            security_gate
            ;;

        network)
            network_gate
            ;;

        *)
            echo
            echo "Usage:"
            echo "  09-toolkit-control.sh state"
            echo "  09-toolkit-control.sh check"
            echo "  09-toolkit-control.sh start"
            echo "  09-toolkit-control.sh stop"
            echo "  09-toolkit-control.sh restart"
            echo "  09-toolkit-control.sh recover"
            echo "  09-toolkit-control.sh repair"
            echo "  09-toolkit-control.sh security"
            echo "  09-toolkit-control.sh network"
            echo
            exit 1
            ;;
    esac

fi
