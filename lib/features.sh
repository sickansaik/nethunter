#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Feature Registry
###############################################################################

FEATURES=()

feature_register() {
    local id="$1"
    local name="$2"
    local description="$3"
    local handler="$4"

    FEATURES+=("$id|$name|$description|$handler")
}

feature_exists() {
    local wanted="$1"
    local entry

    for entry in "${FEATURES[@]}"; do
        IFS='|' read -r id name description handler <<< "$entry"

        if [[ "$id" == "$wanted" ]]; then
            return 0
        fi
    done

    return 1
}

feature_name() {
    local wanted="$1"
    local entry

    for entry in "${FEATURES[@]}"; do
        IFS='|' read -r id name description handler <<< "$entry"

        if [[ "$id" == "$wanted" ]]; then
            echo "$name"
            return 0
        fi
    done

    return 1
}

feature_description() {
    local wanted="$1"
    local entry

    for entry in "${FEATURES[@]}"; do
        IFS='|' read -r id name description handler <<< "$entry"

        if [[ "$id" == "$wanted" ]]; then
            echo "$description"
            return 0
        fi
    done

    return 1
}

feature_handler() {
    local wanted="$1"
    local entry

    for entry in "${FEATURES[@]}"; do
        IFS='|' read -r id name description handler <<< "$entry"

        if [[ "$id" == "$wanted" ]]; then
            echo "$handler"
            return 0
        fi
    done

    return 1
}

feature_list() {
    local entry

    for entry in "${FEATURES[@]}"; do
        IFS='|' read -r id name description handler <<< "$entry"

        printf '%-18s %-24s %s\n' \
            "$id" \
            "$name" \
            "$description"
    done
}

feature_run() {
    local wanted="$1"
    local handler

    if ! feature_exists "$wanted"; then
        echo "[✗] Unknown feature: $wanted"
        return 1
    fi

    handler="$(feature_handler "$wanted")"

    if [[ ! -x "$handler" ]]; then
        echo "[✗] Feature handler unavailable: $handler"
        return 1
    fi

    "$handler" "${@:2}"
}
