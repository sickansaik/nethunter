#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit v0.5.0
# Feature CLI
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/feature-loader.sh"

usage() {
    echo
    echo "NetHunter Toolkit Feature CLI"
    echo
    echo "Usage:"
    echo "  ./feature.sh list"
    echo "  ./feature.sh info <feature>"
    echo "  ./feature.sh run <feature>"
    echo
}

case "${1:-}" in

    list)
        echo
        echo "============================================"
        echo "        AVAILABLE FEATURES"
        echo "============================================"
        echo
        printf '%-18s %-24s %s\n' \
            "ID" \
            "NAME" \
            "DESCRIPTION"
        echo "----------------------------------------------------------------"
        feature_list
        ;;

    info)
        if [[ -z "${2:-}" ]]; then
            usage
            exit 1
        fi

        if ! feature_exists "$2"; then
            echo "[✗] Unknown feature: $2"
            exit 1
        fi

        echo
        echo "Feature     : $2"
        echo "Name        : $(feature_name "$2")"
        echo "Description : $(feature_description "$2")"
        echo "Handler     : $(feature_handler "$2")"
        ;;

    run)
        if [[ -z "${2:-}" ]]; then
            usage
            exit 1
        fi

        feature_run "$2" "${@:3}"
        ;;

    *)
        usage
        exit 1
        ;;

esac
