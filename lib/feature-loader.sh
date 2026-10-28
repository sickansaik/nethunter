#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# v0.5.0 Feature Loader
###############################################################################

FEATURE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$FEATURE_ROOT/features.sh"

feature_register \
    "runtime" \
    "Runtime Control" \
    "Control X11/XFCE runtime" \
    "$FEATURE_ROOT/../modules/features/runtime.sh"

feature_register \
    "network" \
    "Network Tools" \
    "Network discovery and diagnostics" \
    "$FEATURE_ROOT/../modules/features/network.sh"

feature_register \
    "system" \
    "System Diagnostics" \
    "System health and diagnostics" \
    "$FEATURE_ROOT/../modules/features/system.sh"

feature_register \
    "security" \
    "Security Tools" \
    "Security-oriented toolkit functions" \
    "$FEATURE_ROOT/../modules/features/security.sh"
