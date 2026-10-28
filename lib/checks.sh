#!/data/data/com.termux/files/usr/bin/bash

check_internet() {

    if ping -c 1 1.1.1.1 >/dev/null 2>&1
    then
        log_ok "Internetanslutning OK"
    else
        log_error "Ingen internetanslutning"
        return 1
    fi

}

check_cpu() {

    local termux_arch
    local kernel_arch
    local android_abi

    termux_arch="$(dpkg --print-architecture 2>/dev/null || true)"
    kernel_arch="$(uname -m 2>/dev/null || true)"
    android_abi="$(getprop ro.product.cpu.abi 2>/dev/null || true)"

    if [[ -n "$termux_arch" ]]; then
        CPU="$termux_arch"
    elif [[ -n "$android_abi" ]]; then
        case "$android_abi" in
            arm64-v8a)
                CPU="aarch64"
                ;;
            armeabi-v7a|armeabi)
                CPU="arm"
                ;;
            *)
                CPU="$android_abi"
                ;;
        esac
    else
        CPU="$kernel_arch"
    fi

    log_ok "CPU: $CPU"

    if [[ -n "$kernel_arch" && "$kernel_arch" != "$CPU" ]]; then
        log_info "Kernelarkitektur: $kernel_arch"
    fi

}

check_android() {

    VERSION=$(getprop ro.build.version.release)
    log_ok "Android $VERSION"

}

check_storage() {

    SPACE=$(df -h "$HOME" | awk 'NR==2 {print $4}')
    log_ok "Ledigt utrymme: $SPACE"

}

check_ubuntu() {

    if proot-distro list | grep -q "\* ubuntu"; then
        log_ok "Ubuntu installerad"
    else
        log_warn "Ubuntu ej installerad"
    fi

}
