#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Ubuntu 24.04 GUI Runtime
#
# Architecture:
#   Termux
#      -> Termux:X11
#      -> proot-distro Ubuntu 24.04
#      -> dbus-launch
#      -> XFCE
#
# IMPORTANT:
#   This runtime intentionally does NOT use Kali XFCE.
#   It uses the verified Ubuntu 24.04 environment.
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/functions.sh"
source "$SCRIPT_DIR/lib/runtime.sh"

NHT_DISPLAY="$RUNTIME_X11_DISPLAY"
NHT_UBUNTU="ubuntu"

NHT_RUNTIME_DIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp/nethunter-toolkit"
NHT_PID_FILE="$NHT_RUNTIME_DIR/ubuntu-xfce.pid"
NHT_LOG_FILE="$NHT_RUNTIME_DIR/ubuntu-xfce.log"

mkdir -p "$NHT_RUNTIME_DIR"

###############################################################################
# Logging
###############################################################################

log_ok() {
    echo "[✓] $*"
}

log_info() {
    echo "[i] $*"
}

log_warn() {
    echo "[!] $*"
}

log_error() {
    echo "[✗] $*"
}

###############################################################################
# X11
###############################################################################


check_x11() {

    log_info "Kontrollerar Termux:X11..."

    if runtime_x11_start; then
        log_ok "Termux:X11 runtime GREEN"
        return 0
    fi

    log_error "Termux:X11 kunde inte återställas"
    return 1
}

###############################################################################
# Ubuntu
###############################################################################

check_ubuntu() {

    log_info "Kontrollerar Ubuntu..."

    if ! runtime_ubuntu_login "$NHT_UBUNTU" -- true >/dev/null 2>&1; then
        log_error "Ubuntu kan inte startas"
        return 1
    fi

    local version

    version="$(
        runtime_ubuntu_login "$NHT_UBUNTU" -- \
        bash -lc 'grep "^VERSION_ID=" /etc/os-release' 2>/dev/null || true
    )"

    if [[ "$version" == *24.04* ]]; then
        log_ok "Ubuntu 24.04 tillgänglig"
    else
        log_warn "Ubuntu-version: ${version:-okänd}"
    fi

    if runtime_ubuntu_login "$NHT_UBUNTU" -- \
        bash -lc 'command -v xfce4-session >/dev/null 2>&1'
    then
        log_ok "XFCE finns"
    else
        log_error "XFCE saknas"
        return 1
    fi

    if runtime_ubuntu_login "$NHT_UBUNTU" -- \
        bash -lc 'command -v dbus-launch >/dev/null 2>&1'
    then
        log_ok "DBus-launch finns"
    else
        log_error "dbus-launch saknas"
        return 1
    fi

    return 0
}

###############################################################################
# Ubuntu -> X11
###############################################################################

test_x11() {

    log_info "Testar Ubuntu → Termux:X11..."

    if runtime_ubuntu_x11_test; then
        log_ok "Ubuntu → Termux:X11 fungerar"
        return 0
    fi

    log_error "Ubuntu kan inte ansluta till Termux:X11"
    return 1
}

###############################################################################
# PID
###############################################################################

get_pid() {

    if [[ -f "$NHT_PID_FILE" ]]; then
        cat "$NHT_PID_FILE"
    fi
}

pid_running() {

    local pid

    pid="$(get_pid)"

    [[ -n "$pid" ]] &&
    kill -0 "$pid" 2>/dev/null
}

###############################################################################
# Real XFCE detection
###############################################################################

xfce_running() {
    runtime_xfce_running
}

###############################################################################
# Start
###############################################################################

start_xfce() {

    if xfce_running; then
        log_ok "XFCE kör redan"
        return 0
    fi

    log_info "Startar Ubuntu XFCE..."

    rm -f "$NHT_LOG_FILE"

    runtime_ubuntu_login "$NHT_UBUNTU" -- \
        bash -lc '
            pkill -TERM -x xfce4-panel 2>/dev/null || true
            pkill -TERM -x xfdesktop 2>/dev/null || true
            pkill -TERM -x xfwm4 2>/dev/null || true
            pkill -TERM -x xfce4-session 2>/dev/null || true
            pkill -TERM -x dbus-run-session 2>/dev/null || true
        ' >/dev/null 2>&1 || true

    sleep 2

    nohup bash -c '
        runtime_file="$1"
        ubuntu_name="$2"
        display_value="$3"

        source "$runtime_file" || exit 1

        runtime_ubuntu_login "$ubuntu_name" -- \
            bash -lc "
                export DISPLAY='\''$display_value'\''
                export XDG_RUNTIME_DIR='\''/tmp/runtime-root'\''
                export XDG_CURRENT_DESKTOP='\''XFCE'\''
                export XDG_SESSION_DESKTOP='\''xfce'\''
                export XDG_SESSION_TYPE='\''x11'\''
                export GDK_BACKEND='\''x11'\''
                export XFCE_DISABLE_WM_CHECK=1

                mkdir -p \"\$XDG_RUNTIME_DIR\"
                chmod 700 \"\$XDG_RUNTIME_DIR\"

                exec dbus-run-session -- startxfce4
            "
    ' _ "$SCRIPT_DIR/lib/runtime.sh" "$NHT_UBUNTU" "$NHT_DISPLAY" \
        >"$NHT_LOG_FILE" 2>&1 </dev/null &

    local pid=$!

    echo "$pid" > "$NHT_PID_FILE"

    log_info "XFCE launch-PID: $pid"

    for _ in $(seq 1 15); do

        if xfce_running; then
            log_ok "Ubuntu XFCE startad"
            return 0
        fi

        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi

        sleep 1
    done

    log_error "XFCE kunde inte startas"

    echo
    echo "=== XFCE LOG ==="

    cat "$NHT_LOG_FILE" 2>/dev/null || true

    return 1
}

###############################################################################
# Stop
###############################################################################

stop_xfce() {

    log_info "Stoppar Ubuntu XFCE..."

    local pid

    pid="$(get_pid)"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        sleep 2
    fi

    # Säkerhetsstädning inne i Ubuntu.
    runtime_ubuntu_login "$NHT_UBUNTU" -- \
        bash -lc '
            pkill -TERM -x xfce4-session 2>/dev/null || true
            pkill -TERM -x xfwm4 2>/dev/null || true
            pkill -TERM -x xfce4-panel 2>/dev/null || true
            pkill -TERM -x xfdesktop 2>/dev/null || true
            pkill -TERM -x dbus-launch 2>/dev/null || true
        ' >/dev/null 2>&1 || true

    rm -f "$NHT_PID_FILE"

    log_ok "Ubuntu XFCE stoppad"
}

###############################################################################
# Status
###############################################################################

status() {

    echo
    echo "============================================"
    echo "        UBUNTU GUI RUNTIME STATUS"
    echo "============================================"
    echo

    if check_x11 >/dev/null 2>&1; then
        log_ok "Termux:X11 socket       : OK"
    else
        log_warn "Termux:X11 socket       : STOPPED"
    fi

    if runtime_ubuntu_login "$NHT_UBUNTU" -- true >/dev/null 2>&1; then
        log_ok "Ubuntu                  : READY"
    else
        log_warn "Ubuntu                  : FAILED"
    fi

    if test_x11 >/dev/null 2>&1; then
        log_ok "Ubuntu → X11            : GREEN"
    else
        log_warn "Ubuntu → X11            : FAILED"
    fi

    if xfce_running; then

        log_ok "XFCE                    : RUNNING"

        local pid
        pid="$(get_pid)"

        if [[ -n "$pid" ]]; then
            echo "                           PID=$pid"
        fi

        return 0
    fi

    log_warn "XFCE                    : STOPPED"

    return 1
}

###############################################################################
# Full start
###############################################################################

start() {

    echo
    echo "============================================"
    echo "      NETHUNTER TOOLKIT UBUNTU GUI"
    echo "============================================"
    echo

    export DISPLAY="$NHT_DISPLAY"

    check_ubuntu || return 1
    check_x11 || return 1
    test_x11 || return 1
    start_xfce || return 1

    echo
    echo "============================================"
    log_ok "UBUNTU GUI RUNTIME OPERATIONAL"
    echo "============================================"

    status
}

###############################################################################
# Restart
###############################################################################

restart() {

    stop_xfce
    sleep 2
    start
}

###############################################################################
# Repair compatibility
###############################################################################

repair() {
    echo
    log_info "GUI repair ägs nu av Toolkit Control Engine."
    echo
    echo "Använd:"
    echo "  nht gui repair"
    echo
    echo "eller:"
    echo "  modules/09-toolkit-control.sh repair"
    echo
    log_error "Direkt repair via ubuntu-gui.sh stöds inte längre."
    return 1
}

###############################################################################
# Main
###############################################################################

case "${1:-status}" in

    start)
        start
        ;;

    stop)
        stop_xfce
        ;;

    restart)
        restart
        ;;

    repair)
        repair
        ;;

    status)
        status
        ;;

    *)
        echo "Usage:"
        echo "  $0 start"
        echo "  $0 stop"
        echo "  $0 restart"
        echo "  $0 repair"
        echo "  $0 status"
        exit 1
        ;;

esac
