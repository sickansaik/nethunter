#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 08 - Desktop Shortcuts
#
# Makes the installed command-line tools reachable from the XFCE GUI:
#   * installs a GUI terminal (xfce4-terminal) if missing,
#   * installs a small launcher helper (/usr/local/bin/nht-tool) in Ubuntu,
#   * writes .desktop launchers to the applications menu AND the desktop,
#     so the tools show up as clickable icons instead of an empty desktop.
#
# Best-effort: a missing tool is skipped, and the module never fails the
# whole installation over cosmetics.
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/runtime.sh"

title
log_info "Lägger till skrivbords- och menygenvägar för verktygen"

###############################################################################
# GUI terminal
#
# The launchers open in a terminal window. Make sure one exists; XFCE's
# "Terminal Emulator" menu entry needs an actual terminal installed.
###############################################################################

if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc \
    'command -v xfce4-terminal >/dev/null 2>&1'
then
    log_info "Installerar xfce4-terminal"
    if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update &&
        apt-get install -y xfce4-terminal
    '
    then
        log_warn "xfce4-terminal kunde inte installeras; genvägarna kan sakna terminal."
    fi
fi

###############################################################################
# Launcher helper + .desktop files (written inside Ubuntu PRoot)
#
# All of the following runs in a single Ubuntu shell. It is self-contained so
# that a failure stays inside the module and is reported as a warning.
###############################################################################

if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc '
set -u

APP_DIR="/usr/share/applications"
DESK_DIR="/root/Desktop"
BIN="/usr/local/bin/nht-tool"

mkdir -p "$APP_DIR" "$DESK_DIR" "$(dirname "$BIN")"

# --- Launcher helper -------------------------------------------------------
# Usage: nht-tool <command> [friendly name]
# Prints a short banner and the tool help, then drops into an interactive
# shell so the user can type the real command.
cat > "$BIN" <<"EOS"
#!/bin/bash
tool="$1"
name="${2:-$1}"
echo "============================================"
echo "  NetHunter  ·  $name"
echo "============================================"
echo
if command -v "$tool" >/dev/null 2>&1; then
    "$tool" --help 2>&1 | head -n 20 || "$tool" -h 2>&1 | head -n 20 || true
    echo
    echo "[i] Skriv ditt kommando nedan. Avsluta med: exit"
else
    echo "[!] $tool är inte installerat."
fi
echo
exec bash
EOS
chmod +x "$BIN"

# --- Tool table ------------------------------------------------------------
# cmd|Name|Comment|Icon
TOOLS="
nmap|Nmap|Nätverks- och portskanner|network-workgroup
sqlmap|sqlmap|Automatisk SQL-injection|applications-internet
hydra|Hydra|Lösenords-bruteforce|dialog-password
gobuster|Gobuster|Katalog- och DNS-brute|folder-remote
ffuf|ffuf|Webb-fuzzing|applications-internet
nc|Netcat|TCP/UDP-verktyg|network-wired
tcpdump|tcpdump|Paketsniffer|network-transmit-receive
whois|Whois|Domänuppslag|dialog-information
dig|dig|DNS-uppslag|dialog-information
"

make_launcher() {
    # $1 cmd  $2 name  $3 comment  $4 icon
    local cmd="$1" name="$2" comment="$3" icon="$4"
    command -v "$cmd" >/dev/null 2>&1 || return 1
    local file="$APP_DIR/nht-${cmd}.desktop"
    cat > "$file" <<EOD
[Desktop Entry]
Version=1.0
Type=Application
Name=${name}
GenericName=NetHunter
Comment=${comment}
Exec=xfce4-terminal --title="NetHunter: ${name}" -e "nht-tool ${cmd} ${name}"
Icon=${icon}
Terminal=false
Categories=System;Network;Security;X-NetHunter;
Keywords=nethunter;security;pentest;
EOD
    # Desktop copy (clickable icon on the home screen)
    cp "$file" "$DESK_DIR/nht-${cmd}.desktop"
    chmod +x "$DESK_DIR/nht-${cmd}.desktop"
    return 0
}

count=0
while IFS="|" read -r cmd name comment icon; do
    [ -z "$cmd" ] && continue
    if make_launcher "$cmd" "$name" "$comment" "$icon"; then
        count=$((count + 1))
    fi
done <<EOT
$(printf "%s\n" "$TOOLS")
EOT

# --- Plain NetHunter terminal ---------------------------------------------
cat > "$APP_DIR/nht-terminal.desktop" <<EOD
[Desktop Entry]
Version=1.0
Type=Application
Name=NetHunter Terminal
Comment=Terminal med alla NetHunter-verktyg
Exec=xfce4-terminal --title="NetHunter Terminal"
Icon=utilities-terminal
Terminal=false
Categories=System;X-NetHunter;
EOD
cp "$APP_DIR/nht-terminal.desktop" "$DESK_DIR/nht-terminal.desktop"
chmod +x "$DESK_DIR/nht-terminal.desktop"

# Refresh the menu cache if the tool is available.
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo "NHT_LAUNCHERS=$count"
'
then
    log_warn "Genvägarna kunde inte skapas fullständigt."
    exit 0
fi

log_ok "Genvägar klara. Verktygen finns nu i Applications-menyn och på skrivbordet."

exit 0
