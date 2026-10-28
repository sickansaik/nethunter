#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Runtime Manager
# v0.4.3
#
# Central read-only runtime abstraction.
#
# This layer owns runtime detection and state primitives.
# Mutation logic will be migrated in later phases.
###############################################################################

RUNTIME_DIR="${NHT_RUNTIME_DIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp/nethunter-toolkit}"

RUNTIME_X11_DISPLAY="${NHT_X11_DISPLAY:-127.0.0.1:1}"
RUNTIME_UBUNTU="${NHT_UBUNTU:-ubuntu}"

###############################################################################
# Runtime directory
###############################################################################

runtime_dir() {
    echo "$RUNTIME_DIR"
}

###############################################################################
# State
###############################################################################

runtime_prepare_state() {
    mkdir -p "$RUNTIME_DIR"
}

runtime_pid_file() {
    echo "$RUNTIME_DIR/$1.pid"
}

runtime_env_file() {
    echo "$RUNTIME_DIR/runtime.env"
}

runtime_save_pid() {
    local name="$1"
    local pid="$2"

    runtime_prepare_state
    printf '%s\n' "$pid" > "$(runtime_pid_file "$name")"
}

runtime_get_pid() {
    local name="$1"
    local file

    file="$(runtime_pid_file "$name")"

    if [[ -f "$file" ]]; then
        cat "$file"
    fi
}

runtime_pid_running() {
    local name="$1"
    local pid

    pid="$(runtime_get_pid "$name")"

    [[ -n "$pid" ]] &&
        kill -0 "$pid" 2>/dev/null
}

runtime_clear_pid() {
    local name="$1"

    rm -f "$(runtime_pid_file "$name")"
}

runtime_save_env() {
    runtime_prepare_state

    cat > "$(runtime_env_file)" <<ENV
DISPLAY=$RUNTIME_X11_DISPLAY
NHT_RUNTIME_DIR=$RUNTIME_DIR
NHT_UBUNTU=$RUNTIME_UBUNTU
ENV
}

runtime_load_env() {
    local file
    local line
    local key
    local value

    file="$(runtime_env_file)"

    [[ -f "$file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        [[ "$line" == *=* ]] || continue

        key="${line%%=*}"
        value="${line#*=}"

        case "$key" in
            DISPLAY)
                RUNTIME_X11_DISPLAY="$value"
                ;;
            NHT_RUNTIME_DIR)
                RUNTIME_DIR="$value"
                ;;
            NHT_UBUNTU)
                RUNTIME_UBUNTU="$value"
                ;;
        esac
    done < "$file"
}

###############################################################################
# X11 Mutation
###############################################################################

runtime_x11_log() {
    echo "$(runtime_dir)/x11.log"
}

# Display number from RUNTIME_X11_DISPLAY, e.g. 127.0.0.1:1 -> 1.
runtime_x11_display_number() {
    local num="${RUNTIME_X11_DISPLAY##*:}"
    echo "${num%%.*}"
}

# Bring the Termux:X11 Android app to the foreground. The X server needs the
# app as its drawing surface: without it the server stays alive but never
# accepts connections. Best effort - returns 1 when Termux's `am` is missing
# or the launch fails, so callers can fall back to asking the user.
runtime_x11_open_app() {
    command -v am >/dev/null 2>&1 || return 1
    am start --user 0 \
        -n "${NHT_X11_APP_ACTIVITY:-com.termux.x11/com.termux.x11.MainActivity}" \
        >/dev/null 2>&1
}

# Report whether the Termux:X11 app process is currently running.
runtime_x11_app_running() {
    pgrep -f "com.termux.x11" >/dev/null 2>&1
}

# Stop every termux-x11 server, not only the one the Toolkit started. A server
# left over from a manual `termux-x11` run keeps the display lock and makes a
# fresh start fail with "server already running".
runtime_x11_kill_servers() {
    local num
    local tmp_dir="${PREFIX:-/data/data/com.termux/files/usr}/tmp"

    num="$(runtime_x11_display_number)"

    if [[ -f "$(runtime_pid_file x11)" ]]; then
        runtime_clear_pid "x11"
    fi

    pkill -f "com.termux.x11.CmdEntryPoint" 2>/dev/null || true
    pkill -f "termux-x11 :" 2>/dev/null || true
    sleep 1

    rm -f "$tmp_dir/.X${num}-lock" "$tmp_dir/.X11-unix/X${num}" 2>/dev/null || true
}

runtime_x11_start() {

    runtime_prepare_state

    local log
    local pid
    local num
    local timeout
    local waited=0
    local app_opened=0

    log="$(runtime_x11_log)"
    num="$(runtime_x11_display_number)"
    timeout="${NHT_X11_START_TIMEOUT:-30}"

    echo "[i] Checking Termux:X11 TCP..."

    ###########################################################################
    # Already healthy
    ###########################################################################

    if runtime_x11_running; then
        echo "[✓] Termux:X11 TCP already running"
        runtime_save_env
        return 0
    fi

    ###########################################################################
    # Clean up stale servers (Toolkit-owned or left over from manual runs)
    ###########################################################################

    echo "[i] Clearing any stale Termux:X11 servers..."
    runtime_x11_kill_servers

    ###########################################################################
    # Make sure the Termux:X11 app is up - it is the X server's screen.
    ###########################################################################

    if ! runtime_x11_app_running; then
        echo "[i] Opening the Termux:X11 app..."
        if runtime_x11_open_app; then
            app_opened=1
            sleep 2
        else
            echo "[!] Could not open the Termux:X11 app automatically."
            echo "[!] Open the Termux:X11 app manually, then retry."
        fi
    else
        app_opened=1
    fi

    ###########################################################################
    # Start Termux:X11 on the configured TCP display
    ###########################################################################

    echo "[i] Starting Termux:X11 on TCP display :$num..."

    rm -f "$log"

    termux-x11 ":$num" -listen tcp >"$log" 2>&1 &
    pid=$!

    runtime_save_pid "x11" "$pid"

    echo "[i] X11 PID: $pid"
    echo "[i] Waiting for X11 TCP transport (up to ${timeout}s)..."

    ###########################################################################
    # Wait for X11
    ###########################################################################

    while (( waited < timeout )); do

        if runtime_x11_running; then

            runtime_save_env

            echo "[✓] X11 TCP connection verified"
            echo "[✓] DISPLAY=$RUNTIME_X11_DISPLAY"

            return 0
        fi

        if ! kill -0 "$pid" 2>/dev/null; then
            echo "[✗] Termux:X11 process exited"
            break
        fi

        sleep 1
        waited=$(( waited + 1 ))
    done

    ###########################################################################
    # Failure - give a diagnosis, not just a stack of red marks
    ###########################################################################

    echo "[✗] Termux:X11 TCP failed to start"

    if kill -0 "$pid" 2>/dev/null; then
        # Server is alive but nothing connected: almost always the app.
        echo
        echo "[!] The X server is running but no display connected."
        if (( app_opened )); then
            echo "[!] Switch to the Termux:X11 app once (it must be in the"
            echo "    foreground), then run Start again."
        else
            echo "[!] The Termux:X11 app is not open. Open it, leave it"
            echo "    running, then run Start again."
        fi
        echo "[!] Tip: pull down the Termux notification and tap"
        echo "    'Acquire wakelock' so Android does not freeze it."
        kill "$pid" 2>/dev/null || true
    fi

    if [[ -s "$log" ]]; then
        echo
        echo "=== X11 LOG ==="
        cat "$log"
    fi

    runtime_clear_pid "x11"

    return 1
}

###############################################################################
# X11 Status
###############################################################################

runtime_x11_status() {

    if [[ -S "$(runtime_x11_socket)" ]]; then
        echo "RUNNING"
        return 0
    fi

    echo "STOPPED"
    return 1
}

###############################################################################
# X11 Bridge
###############################################################################

runtime_x11_bridge_test() {

    echo "[i] Testing X11 TCP transport..."

    if ! runtime_x11_running; then
        echo "[✗] Termux:X11 TCP display is unavailable"
        return 1
    fi

    echo "[✓] Host X11 TCP connection is available"

    echo "[i] Testing Kali X11 connection..."

    nethunter \
        -- \
        bash -lc "
            export DISPLAY='$RUNTIME_X11_DISPLAY'

            echo '[i] DISPLAY=$DISPLAY'

            if ! command -v xdpyinfo >/dev/null 2>&1; then
                echo '[✗] xdpyinfo not installed'
                exit 1
            fi

            if xdpyinfo >/tmp/nht-x11-test.out 2>/tmp/nht-x11-test.err; then

                echo '[✓] X11 connection established'

                echo
                echo '=== X11 SERVER ==='

                grep -E \
                    '^(name of display|version number|dimensions|depth of root)' \
                    /tmp/nht-x11-test.out

                echo
                echo '[✓] Kali → Termux:X11 TCP bridge GREEN'

            else

                echo '[✗] X11 connection failed'
                cat /tmp/nht-x11-test.err
                exit 1

            fi
        "
}

runtime_x11_bridge_exec() {

    local command_string="$*"

    if [[ -z "$command_string" ]]; then
        echo "[✗] No Kali command supplied"
        return 1
    fi

    nethunter \
        -- \
        bash -lc "
            export DISPLAY='$RUNTIME_X11_DISPLAY'
            $command_string
        "
}


###############################################################################
# X11
###############################################################################

runtime_x11_socket() {
    # TCP transport: no filesystem X11 socket is required.
    echo "tcp://127.0.0.1:6001"
}

runtime_x11_running() {
    DISPLAY="$RUNTIME_X11_DISPLAY" \
        xdpyinfo >/dev/null 2>&1
}

runtime_x11_test() {
    DISPLAY="$RUNTIME_X11_DISPLAY" \
        xdpyinfo >/dev/null 2>&1
}

###############################################################################
# Ubuntu / PRoot
###############################################################################

runtime_ubuntu_login() {
    local termux_arch
    local uname_arch
    local personality

    termux_arch="$(dpkg --print-architecture 2>/dev/null || true)"
    uname_arch="$(uname -m 2>/dev/null || true)"
    personality="$(setarch --show 2>/dev/null || true)"

    if [[ "$termux_arch" == "aarch64" ]] &&
       [[ "$uname_arch" != "aarch64" || "$personality" == "PER_LINUX32" ]]
    then
        command -v setarch >/dev/null 2>&1 || return 1

        setarch aarch64 proot-distro login "$@"
        return $?
    fi

    proot-distro login "$@"
}

runtime_ubuntu_ready() {
    command -v proot-distro >/dev/null 2>&1 &&
        runtime_ubuntu_login "$RUNTIME_UBUNTU" -- true >/dev/null 2>&1
}

runtime_ubuntu_x11_test() {
    runtime_ubuntu_ready || return 1
    runtime_x11_running || return 1

    runtime_ubuntu_login "$RUNTIME_UBUNTU" -- \
        env DISPLAY="$RUNTIME_X11_DISPLAY" \
        xdpyinfo >/dev/null 2>&1
}

###############################################################################
# XFCE
###############################################################################

runtime_xfce_running() {
    runtime_ubuntu_ready || return 1

    runtime_ubuntu_login "$RUNTIME_UBUNTU" -- \
        bash -lc '
            pgrep -x xfce4-session >/dev/null 2>&1 &&
            pgrep -x xfwm4 >/dev/null 2>&1 &&
            pgrep -x xfce4-panel >/dev/null 2>&1 &&
            pgrep -x xfdesktop >/dev/null 2>&1
        '
}

###############################################################################
# D-Bus
###############################################################################


runtime_ubuntu_dbus_running() {
    runtime_ubuntu_ready || return 1

    runtime_ubuntu_login "$RUNTIME_UBUNTU" -- \
        bash -lc '
            pgrep -af "dbus-run-session.*startxfce4" >/dev/null 2>&1 ||
            pgrep -x dbus-daemon >/dev/null 2>&1
        '
}

###############################################################################
# PulseAudio
###############################################################################

runtime_pulse_host_ready() {
    command -v pactl >/dev/null 2>&1 &&
        pactl info >/dev/null 2>&1
}

runtime_pulse_ubuntu_ready() {
    runtime_ubuntu_ready || return 1

    command -v pulse_test_ubuntu >/dev/null 2>&1 || return 1

    pulse_test_ubuntu >/dev/null 2>&1
}

###############################################################################
# Composite runtime checks
###############################################################################

runtime_gui_ready() {

    runtime_ubuntu_ready || return 1
    runtime_x11_test || return 1
    runtime_ubuntu_x11_test || return 1
    runtime_xfce_running || return 1

    return 0
}


###############################################################################
# Runtime state
###############################################################################

