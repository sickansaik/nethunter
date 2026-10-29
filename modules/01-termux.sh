#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

source "$(dirname "$0")/../lib/colors.sh"

title
info "Modul 01 - Termux"

pkg update -y || exit "$?"
pkg upgrade -y || exit "$?"

# Enable the extra repositories first. termux-x11-nightly lives in x11-repo,
# so the repo must be active (and its package index refreshed) before we can
# install it in the same run.
pkg install -y \
x11-repo \
root-repo || exit "$?"

pkg update -y || exit "$?"

pkg install -y \
git \
curl \
wget \
proot-distro \
pulseaudio \
termux-x11-nightly \
xorg-xdpyinfo \
nano \
vim \
zip \
unzip \
tar \
python \
coreutils \
findutils \
util-linux || exit "$?"

ok "Termux är uppdaterat."
