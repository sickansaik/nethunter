#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Module 11 - Touch UI
#
# Gives the Ubuntu/XFCE desktop a clean, touch-friendly "Linux phone" look:
#   * a bottom dock (xfce4-panel) with large, finger-sized icons:
#     an app menu, the NetHunter tools, and a show-desktop button,
#   * a dark theme (Adwaita-dark / Greybird-dark if available) with a dark
#     icon theme and a large cursor,
#   * a dark gradient wallpaper instead of the empty grey desktop.
#
# All configuration is written as XFCE "xfconf" XML files inside the Ubuntu
# PRoot, so it is deterministic and applied the next time the desktop starts.
# Any existing config is backed up first (…xml.nht-bak). Best-effort: a real
# file-write failure is surfaced as a module warning, never fails the whole
# installation over cosmetics.
#
# NOTE: XFCE loads this config at session start. If the desktop is already
# running, restart it (toolkit.sh -> 8 Ubuntu GUI -> 3 Restart) to see it.
###############################################################################

source "$(dirname "$0")/../lib/colors.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/runtime.sh"

title
log_info "Ställer in touch-vänligt skrivbord (dock, mörkt tema, bakgrund)"

###############################################################################
# Optional nicer dark GTK theme (best-effort, never fatal)
###############################################################################

runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc '
    export DEBIAN_FRONTEND=noninteractive
    command -v apt-get >/dev/null 2>&1 || exit 0
    dpkg -s greybird-gtk-theme >/dev/null 2>&1 && exit 0
    apt-get install -y greybird-gtk-theme >/dev/null 2>&1 || true
' || true

###############################################################################
# Write the XFCE configuration (runs inside Ubuntu PRoot)
###############################################################################

if ! runtime_ubuntu_login "$RUNTIME_UBUNTU" -- bash -lc '
set -u

XFCONF="/root/.config/xfce4/xfconf/xfce-perchannel-xml"
PANELDIR="/root/.config/xfce4/panel"
fail=0

mkdir -p "$XFCONF" "$PANELDIR" || fail=1

backup() {
    # Keep a one-time backup of anything we overwrite.
    [ -f "$1" ] && [ ! -f "$1.nht-bak" ] && cp "$1" "$1.nht-bak"
    return 0
}

# Pick a dark GTK theme that actually exists on this system.
THEME="Adwaita-dark"
if [ -d /usr/share/themes/Greybird-dark ]; then
    THEME="Greybird-dark"
fi

############################################################################
# 1) Appearance: dark theme, dark icons, big cursor, readable font
############################################################################
backup "$XFCONF/xsettings.xml"
if ! cat > "$XFCONF/xsettings.xml" <<EOX
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="$THEME"/>
    <property name="IconThemeName" type="string" value="elementary-xfce-dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Sans 11"/>
    <property name="CursorThemeSize" type="int" value="48"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
  </property>
</channel>
EOX
then
    fail=1
fi

############################################################################
# 2) Window manager: dark theme, larger title buttons for touch
############################################################################
backup "$XFCONF/xfwm4.xml"
if ! cat > "$XFCONF/xfwm4.xml" <<EOX
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Default"/>
    <property name="title_font" type="string" value="Sans Bold 11"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="theme_dark" type="bool" value="true"/>
  </property>
</channel>
EOX
then
    fail=1
fi

############################################################################
# 3) Desktop: dark gradient wallpaper instead of empty grey
############################################################################
backup "$XFCONF/xfce4-desktop.xml"
if ! cat > "$XFCONF/xfce4-desktop.xml" <<EOX
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorscreen" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="2"/>
          <property name="image-style" type="int" value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.058824"/>
            <value type="double" value="0.086275"/>
            <value type="double" value="0.141176"/>
            <value type="double" value="1.000000"/>
          </property>
          <property name="rgba2" type="array">
            <value type="double" value="0.015686"/>
            <value type="double" value="0.027451"/>
            <value type="double" value="0.058824"/>
            <value type="double" value="1.000000"/>
          </property>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="icon-size" type="uint" value="48"/>
    <property name="style" type="int" value="2"/>
  </property>
</channel>
EOX
then
    fail=1
fi

############################################################################
# 4) Bottom dock: big launcher icons for the NetHunter tools
#
# Layout: [App menu] [spacer] [Terminal][nmap][sqlmap][hydra][gobuster][ffuf]
#         [spacer] [Show desktop]
############################################################################

# cmd|Friendly name|icon   (cmd empty => special plugin handled below)
LAUNCH="
nht-terminal|NetHunter Terminal|utilities-terminal
nmap|Nmap|network-workgroup
sqlmap|sqlmap|applications-internet
hydra|Hydra|dialog-password
gobuster|Gobuster|folder-remote
ffuf|ffuf|applications-internet
"

# Build the plugin-ids list and the <plugins> blocks.
ids="    <value type=\"int\" value=\"1\"/>
    <value type=\"int\" value=\"2\"/>"
plugins="  <property name=\"plugin-1\" type=\"string\" value=\"applicationsmenu\">
    <property name=\"show-button-title\" type=\"bool\" value=\"false\"/>
    <property name=\"button-icon\" type=\"string\" value=\"start-here\"/>
  </property>
  <property name=\"plugin-2\" type=\"string\" value=\"separator\">
    <property name=\"expand\" type=\"bool\" value=\"true\"/>
    <property name=\"style\" type=\"uint\" value=\"0\"/>
  </property>"

pid=2
while IFS="|" read -r cmd name icon; do
    [ -z "$cmd" ] && continue
    pid=$((pid + 1))
    ldir="$PANELDIR/launcher-$pid"
    mkdir -p "$ldir" || fail=1

    if [ "$cmd" = "nht-terminal" ]; then
        exec_line="xfce4-terminal --title=\"NetHunter Terminal\""
    else
        exec_line="xfce4-terminal --title=\"NetHunter: $name\" -e \"nht-tool $cmd $name\""
    fi

    if ! cat > "$ldir/nht-$cmd.desktop" <<EOD
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=NetHunter
Exec=$exec_line
Icon=$icon
Terminal=false
Categories=System;X-NetHunter;
EOD
    then
        fail=1
    fi

    ids="$ids
    <value type=\"int\" value=\"$pid\"/>"
    plugins="$plugins
  <property name=\"plugin-$pid\" type=\"string\" value=\"launcher\">
    <property name=\"items\" type=\"array\">
      <value type=\"string\" value=\"nht-$cmd.desktop\"/>
    </property>
  </property>"
done <<EOT
$(printf "%s\n" "$LAUNCH")
EOT

# Trailing spacer + show-desktop button.
sp=$((pid + 1))
sd=$((pid + 2))
ids="$ids
    <value type=\"int\" value=\"$sp\"/>
    <value type=\"int\" value=\"$sd\"/>"
plugins="$plugins
  <property name=\"plugin-$sp\" type=\"string\" value=\"separator\">
    <property name=\"expand\" type=\"bool\" value=\"true\"/>
    <property name=\"style\" type=\"uint\" value=\"0\"/>
  </property>
  <property name=\"plugin-$sd\" type=\"string\" value=\"showdesktop\"/>"

backup "$XFCONF/xfce4-panel.xml"
if ! cat > "$XFCONF/xfce4-panel.xml" <<EOX
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=0"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="autohide-behavior" type="uint" value="0"/>
      <property name="length" type="uint" value="100"/>
      <property name="size" type="uint" value="60"/>
      <property name="nrows" type="uint" value="1"/>
      <property name="icon-size" type="uint" value="44"/>
      <property name="plugin-ids" type="array">
$ids
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
$plugins
  </property>
</channel>
EOX
then
    fail=1
fi

exit "$fail"
'
then
    log_warn "Touch-skrivbordet kunde inte ställas in fullständigt."
    exit 0
fi

log_ok "Touch-skrivbord klart: dock längst ner, mörkt tema och bakgrund."
log_info "Starta om skrivbordet för att se det (toolkit.sh → 8 → 3 Restart)."

exit 0
