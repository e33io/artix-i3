#!/usr/bin/env bash

# =============================================================================
# System type and HiDPI options for modifying window manager configs
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/system-options.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

while true; do
    clear
    echo "========================================================================"
    echo "The option below lets you select a configuration specific"
    echo "to your monitor type for proper display scaling."
    echo "========================================================================"
    echo "  1) Standard HD (96 dpi settings for 1x scaling)"
    echo "  2) HiDPI (192 dpi settings for 2x scaling)"
    echo "------------------------------------------------------------------------"
    echo
    read -rp "What type of monitor are you using? " n
    case $n in
        1) echo "You chose Standard HD (96 dpi) monitor"
            bash ~/scripts/mod-wm-dpi-scaling.sh
            break;;
        2) echo "You chose HiDPI (192 dpi) monitor"
            break;;
        *) echo "Invalid selection, please enter a number from the list.";;
    esac
done

while true; do
    clear
    echo "========================================================================"
    echo "The option below lets you select a configuration"
    echo "specific to your computer type."
    echo "========================================================================"
    echo "  1) Desktop"
    echo "  2) Laptop"
    echo "  3) VM"
    echo "------------------------------------------------------------------------"
    echo
    read -rp "What type of computer are you using? " n
    case $n in
        1) echo "You chose Desktop computer"
            break;;
        2) echo "You chose Laptop computer"
            bash ~/artix-i3/scripts/mod-laptop.sh
            break;;
        3) echo "You chose VM"
            bash ~/artix-i3/scripts/mod-vm.sh
            break;;
        *) echo "Invalid selection, please enter a number from the list.";;
    esac
done
