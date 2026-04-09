#!/usr/bin/env bash

# =============================================================================
# Modify configs for use with VM devices
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/mod-vm.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Install and enable spice-vdagent
sudo pacman -S --noconfirm --needed spice-vdagent spice-vdagent-openrc
sudo rc-update add spice-vdagent default

# Add xrandr scaling to i3 startup config
printf "%s\n" "" "# Set VM display resolution" \
"\$exec xrandr -s 3840x2160" \
| tee -a ~/.config/i3/startup.conf > /dev/null
# Downscale resolution if Xft.dpi is set to 96 (non-HiDPI)
Xft_dpi=$(grep -E '^Xft\.dpi' ~/.Xresources 2>/dev/null | grep -Eo '[0-9]+')
if [ "$Xft_dpi" = "96" ]; then
    sed -i 's/3840x2160/1920x1080/' ~/.config/i3/startup.conf
fi

# Update LightDM session scaling
sudo sed -i 's/GDK_SCALE=2/GDK_SCALE=1/' /etc/lightdm/Xgsession

# Update plymouth scaling
sudo sed -i 's/DeviceScale=2/DeviceScale=1/' /etc/plymouth/plymouthd.conf
sudo mkinitcpio -p linux
