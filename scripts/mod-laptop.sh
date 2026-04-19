#!/usr/bin/env bash

# =============================================================================
# Modify configs for use with laptop devices
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/mod-laptop.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Install packages and enable services
sudo pacman -S --noconfirm --needed brightnessctl acpid acpid-openrc \
libinput-tools wmctrl
sudo rc-update add acpid default

# Update startup.conf (xautolock command)
sed -i 's/lock\.png/lock\.png \& loginctl suspend/' ~/.config/i3/startup.conf

# Update polybar config.ini (modules)
sed -i -e 's/time pulseaudio eth tray/time battery pulseaudio wlan tray/' \
-e 's/maxlen = .*/maxlen = 140/' -e 's/%a %b/%b/' \
-e 's/%M:%S/%M/' ~/.config/i3/polybar/config.ini
