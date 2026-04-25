#!/usr/bin/env bash

# =============================================================================
# Check for X server and option to install Xorg or XLibre
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/xserver-option.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

set -e

has_xorg=0
has_xlibre=0

command -v Xorg >/dev/null 2>&1 || pacman -Qi xorg-server >/dev/null 2>&1 && has_xorg=1
command -v Xlibre >/dev/null 2>&1 || pacman -Qi xlibre >/dev/null 2>&1 && has_xlibre=1

if [ "$has_xorg" -eq 1 ] || [ "$has_xlibre" -eq 1 ]; then
    echo "X server already installed. Nothing to do."
    exit 0
fi

while true; do
    clear
    echo "========================================================================"
    echo "No X server was found on this system."
    echo "The option below lets you select an X server to install."
    echo "========================================================================"
    echo "  1) Xorg"
    echo "  2) XLibre"
    echo "------------------------------------------------------------------------"
    echo
    read -rp "Which X server would you like to install? " n
    case "$n" in
        1) bash ~/artix-i3/scripts/install-xorg.sh
            break;;
        2) bash ~/artix-i3/scripts/install-xlibre.sh
            break;;
        *) echo "Invalid selection, please enter a number from the list.";;
    esac
done
