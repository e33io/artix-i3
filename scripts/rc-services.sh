#!/usr/bin/env bash

# =============================================================================
# Enable OpenRC Services
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/rc-services.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Enable lightdm
sudo rc-update add lightdm default

# Enable cronie
sudo rc-update add cronie default

# Enable pipewire and wireplumber
rc-update add -U pipewire default
rc-update add -U pipewire-pulse default
rc-update add -U wireplumber default
