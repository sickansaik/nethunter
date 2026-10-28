#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# PulseAudio Runtime Layer
# v0.3.5
###############################################################################

if [[ -n "${PREFIX:-}" ]]; then
    PULSE_RUNTIME_CONFIG_DIR="${PULSE_RUNTIME_CONFIG_DIR:-$PREFIX/tmp/nht-pulse}"
else
    PULSE_RUNTIME_CONFIG_DIR="${PULSE_RUNTIME_CONFIG_DIR:-$HOME/../usr/tmp/nht-pulse}"
fi
PULSE_CLIENT_CONFIG="${PULSE_RUNTIME_CONFIG_DIR}/client.conf"

pulse_log_ok() {
    printf '[✓] %s\n' "$1"
}

pulse_log_warn() {
    printf '[!] %s\n' "$1"
}

pulse_log_error() {
    printf '[✗] %s\n' "$1"
}

pulse_ensure_host() {
    if ! command -v pulseaudio >/dev/null 2>&1; then
        pulse_log_error "Termux pulseaudio saknas."
        return 1
    fi

    if env -u XDG_RUNTIME_DIR pactl info >/dev/null 2>&1; then
        return 0
    fi

    if ! env -u XDG_RUNTIME_DIR pulseaudio --start >/dev/null 2>&1; then
        pulse_log_error "Termux PulseAudio kunde inte startas."
        return 1
    fi

    if env -u XDG_RUNTIME_DIR pactl info >/dev/null 2>&1; then
        pulse_log_ok "Termux PulseAudio startad."
        return 0
    fi

    pulse_log_error "Termux PulseAudio startades men kunde inte verifieras."
    return 1
}

pulse_detect_server() {
    local server=""

    if command -v pactl >/dev/null 2>&1; then
        server="$(env -u XDG_RUNTIME_DIR pactl info 2>/dev/null |
            sed -n 's/^Server String: //p' |
            head -n 1)"
    fi

    if [[ -z "$server" ]]; then
        pulse_log_error "Termux PulseAudio-server kunde inte identifieras."
        return 1
    fi

    printf '%s\n' "$server"
}

pulse_detect_socket() {
    local server

    server="$(pulse_detect_server)" || return 1

    if [[ "$server" == /data/data/com.termux/files/usr/tmp/pulse/native ]]; then
        printf '%s\n' "$server"
        return 0
    fi

    if [[ "$server" == /data/data/com.termux/files/usr/tmp/pulse-*/native ]]; then
        printf '%s\n' "$server"
        return 0
    fi

    if [[ "$server" == unix:* ]]; then
        printf '%s\n' "${server#unix:}"
        return 0
    fi

    pulse_log_error "Oväntad PulseAudio-server: $server"
    return 1
}

pulse_detect_cookie() {
    local cookie="$HOME/.config/pulse/cookie"

    if [[ -r "$cookie" ]]; then
        printf '%s\n' "$cookie"
        return 0
    fi

    pulse_log_error "Termux PulseAudio-cookie kunde inte hittas."
    return 1
}

pulse_prepare_client() {
    local socket
    local cookie

    socket="$(pulse_detect_socket)" || return 1
    cookie="$(pulse_detect_cookie)" || return 1

    mkdir -p "$PULSE_RUNTIME_CONFIG_DIR" || {
        pulse_log_error "Kunde inte skapa PulseAudio runtime-katalog."
        return 1
    }

    chmod 700 "$PULSE_RUNTIME_CONFIG_DIR"

    cat > "$PULSE_CLIENT_CONFIG" <<EOF
# NetHunter Toolkit PulseAudio runtime configuration
# Generated automatically

default-server = unix:$socket
enable-shm = no
EOF

    chmod 600 "$PULSE_CLIENT_CONFIG"

    return 0
}

pulse_exec() {
    pulse_prepare_client || return 1

    env         -u PULSE_SERVER         PULSE_CLIENTCONFIG="$PULSE_CLIENT_CONFIG"         PULSE_COOKIE="$(pulse_detect_cookie)"         "$@"
}

pulse_test_host() {
    if ! command -v pactl >/dev/null 2>&1; then
        pulse_log_error "Termux pactl saknas."
        return 1
    fi

    if env -u XDG_RUNTIME_DIR pactl info >/dev/null 2>&1; then
        pulse_log_ok "Termux PulseAudio fungerar."
        return 0
    fi

    pulse_log_error "Termux PulseAudio fungerar inte."
    return 1
}

pulse_test_ubuntu() {
    local socket
    local cookie

    socket="$(pulse_detect_socket)" || return 1
    cookie="$(pulse_detect_cookie)" || return 1

    runtime_ubuntu_login --shared-x11 "$RUNTIME_UBUNTU" -- bash -c "
        unset PULSE_SERVER
        export PULSE_CLIENTCONFIG='$PULSE_CLIENT_CONFIG'
        export PULSE_COOKIE='$cookie'

        pactl info >/dev/null 2>&1
    "

    if [[ $? -eq 0 ]]; then
        pulse_log_ok "Ubuntu → Termux PulseAudio fungerar."
        return 0
    fi

    pulse_log_error "Ubuntu → Termux PulseAudio fungerar inte."
    return 1
}

pulse_test() {
    echo
    echo "============================================"
    echo "        PULSEAUDIO RUNTIME TEST"
    echo "============================================"
    echo

    pulse_test_host || return 1
    pulse_prepare_client || return 1

    pulse_log_ok "PulseAudio socket: $(pulse_detect_socket)"
    pulse_log_ok "PulseAudio cookie: $(pulse_detect_cookie)"
    pulse_log_ok "PulseAudio SHM: disabled"

    pulse_test_ubuntu || return 1

    echo
    pulse_log_ok "PulseAudio runtime verification klar."
    return 0
}
