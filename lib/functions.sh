#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Common Functions
###############################################################################

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../modules" && pwd)"

###############################################################################
# Kör en modul
###############################################################################

run_module() {

    local module="$1"

    if [[ ! -f "$MODULE_DIR/$module" ]]; then
        log_error "Modulen saknas: $module"
        return 1
    fi

    echo
    info "========================================"
    info "Startar $module"
    info "========================================"

    if bash "$MODULE_DIR/$module"; then
        log_ok "$module klar."
        return 0
    else
        local status=$?
        log_error "$module misslyckades."
        return "$status"
    fi
}

###############################################################################
# Kör flera moduler
###############################################################################

run_modules() {

    local modules=("$@")
    local module
    local total=${#modules[@]}
    local ok_count=0
    local failed_count=0

    ENGINE_FAILURES=0
    ENGINE_WARNINGS=0

    for module in "${modules[@]}"; do

        if run_module "$module"; then
            ((ok_count+=1))
        else
            ((failed_count+=1))
            record_failure "$module returnerade fel."
            log_warn "$module returnerade fel, fortsätter med nästa modul."
        fi

    done

    echo
    echo "============================================"
    echo "        MODULE ENGINE RESULT"
    echo "============================================"
    echo
    echo "Totalt     : $total"
    echo "Godkända   : $ok_count"
    echo "Misslyckade: $failed_count"
    echo "Varningar  : $ENGINE_WARNINGS"
    echo "Fel        : $ENGINE_FAILURES"

    if ! engine_status; then
        log_error "Module Engine avslutad med fel."
        return 1
    fi

    log_ok "Module Engine: alla moduler godkända."
    return 0
}
###############################################################################
# Central statushantering
###############################################################################

ENGINE_FAILURES=0
ENGINE_WARNINGS=0

record_failure() {
    local message="$1"

    ((ENGINE_FAILURES+=1))
    log_error "$message"
}

record_warning() {
    local message="$1"

    ((ENGINE_WARNINGS+=1))
    log_warn "$message"
}

engine_status() {
    if (( ENGINE_FAILURES > 0 )); then
        return 1
    fi

    return 0
}

###############################################################################
# Central systemstatus
###############################################################################

get_system_status() {

    if (( ENGINE_FAILURES > 0 )); then
        echo "FAILED"
        return 1
    fi

    if (( ENGINE_WARNINGS > 0 )); then
        echo "DEGRADED"
        return 2
    fi

    echo "OPERATIONAL"
    return 0
}

print_system_status() {

    local status
    status="$(get_system_status)" || true

    echo
    echo "============================================"
    echo "        SYSTEM STATUS"
    echo "============================================"
    echo

    case "$status" in
        OPERATIONAL)
            log_ok "SYSTEM OPERATIONAL"
            ;;
        DEGRADED)
            log_warn "SYSTEM DEGRADED"
            ;;
        FAILED)
            log_error "SYSTEM FAILED"
            ;;
        *)
            log_error "UNKNOWN SYSTEM STATUS"
            return 1
            ;;
    esac

    echo
    echo "Status     : $status"
    echo "Varningar  : $ENGINE_WARNINGS"
    echo "Fel        : $ENGINE_FAILURES"
    echo "============================================"

    [[ "$status" == "OPERATIONAL" ]]
}

###############################################################################
# Kontrollera kommando
###############################################################################

command_exists() {

    command -v "$1" >/dev/null 2>&1

}

###############################################################################
# Kör kommando med loggning
###############################################################################

run_command() {

    log_info "$*"

    "$@"

}

###############################################################################
# Tidtagning
###############################################################################

timer_start() {

    TIMER_START=$(date +%s)

}

timer_stop() {

    local end

    end=$(date +%s)

    echo "$((end-TIMER_START))"

}

###############################################################################
# V0.3.3 Diagnostic Engine
###############################################################################

diagnostic_status() {

    local status

    status="$(get_system_status)" || true

    case "$status" in
        OPERATIONAL)
            echo "OK"
            return 0
            ;;

        DEGRADED)
            echo "WARNING"
            return 1
            ;;

        FAILED)
            echo "CRITICAL"
            return 2
            ;;

        *)
            echo "UNKNOWN"
            return 3
            ;;
    esac
}

diagnostic_report() {

    echo
    echo "============================================"
    echo "        DIAGNOSTIC ENGINE"
    echo "============================================"
    echo

    echo "Status     : $(get_system_status || true)"
    echo "Diagnostic : $(diagnostic_status || true)"
    echo "Varningar  : $ENGINE_WARNINGS"
    echo "Fel        : $ENGINE_FAILURES"

    echo
    echo "============================================"

    diagnostic_status >/dev/null
}


###############################################################################
# V0.4.0 X11 Runtime
###############################################################################


###############################################################################
# V0.4.0 X11 Bridge
###############################################################################

