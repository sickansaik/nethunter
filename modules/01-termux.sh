#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

source "$(dirname "$0")/../lib/colors.sh"

title
info "Modul 01 - Termux"

pkg update -y || exit "$?"
pkg upgrade -y || exit "$?"

pkg install -y \
git \
curl \
wget \
proot-distro \
pulseaudio \
x11-repo \
root-repo \
nano \
vim \
zip \
unzip \
tar \
python \
coreutils \
findutils || exit "$?"

ok "Termux är uppdaterat."
