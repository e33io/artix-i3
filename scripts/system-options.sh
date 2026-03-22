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
           # Install brightnessctl
           sudo pacman -S --noconfirm --needed brightnessctl
           # Update startup.conf (xautolock command)
           sed -i 's/lock\.png/lock\.png \& zzz/' ~/.config/i3/startup.conf
           # Update polybar config.ini (modules)
           sed -i -e 's/time pulseaudio eth tray/time battery pulseaudio wlan tray/' \
           -e 's/maxlen = .*/maxlen = 140/' -e 's/%a %b/%b/' \
           -e 's/%M:%S/%M/' ~/.config/i3/polybar/config.ini
           break;;
        3) echo "You chose VM"
           # Add xrandr scaling to i3 startup config
           printf "%s\n" "" "# Set display resolution" \
           "\$exec xrandr -s 3840x2160" \
           | tee -a ~/.config/i3/startup.conf > /dev/null
           # Downscale resolution if Xft.dpi is set to 96 (non-HiDPI)
           Xft_dpi=$(grep -E '^Xft\.dpi' ~/.Xresources 2>/dev/null | grep -Eo '[0-9]+')
           if [ "$Xft_dpi" = "96" ]; then
               sed -i 's/3840x2160/1920x1080/' ~/.config/i3/startup.conf
           fi
           # Update LightDM session scale
           sudo sed -i 's/GDK_SCALE=2/GDK_SCALE=1/' /etc/lightdm/Xgsession
           break;;
        *) echo "Invalid selection, please enter a number from the list.";;
    esac
done
