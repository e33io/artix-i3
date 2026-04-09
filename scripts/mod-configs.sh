#!/usr/bin/env bash

# =============================================================================
# Modify Arch configs for use with Artix Linux (OpenRC)
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/mod-configs.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Remove unneeded commands
sed -i '/xss-lock/d' ~/.config/i3/startup.conf
sed -i '/xssproxy/d' ~/.profile

# Add startup commands for xautolock
printf "%s\n" "" "# Start xautolock with i3lock as locker" \
"\$exec xautolock -time 5 -locker \"i3lock -i ~/.cache/i3lock/lock.png\"" \
| tee -a ~/.config/i3/startup.conf > /dev/null

# Add startup commands for pipewire
printf "%s\n" "" "# Start pipewire and wireplumber" \
"exec --no-startup-id pipewire" "exec --no-startup-id wireplumber" \
"exec --no-startup-id pipewire-pulse" \
| tee -a ~/.config/i3/startup.conf > /dev/null

# Add aliases for reboot and power off
printf "%s\n" "" "# Reboot and power off" "alias reboot='loginctl reboot'" \
"alias poweroff='loginctl poweroff'" | tee -a ~/.bashrc > /dev/null

# Replace systemctl with loginctl
sed -i 's/systemctl/loginctl/g' ~/.local/bin/rofi-power.sh

# Replace loginctl lock-session with i3lock
sed -i 's/loginctl lock-session/i3lock -i ~\/\.cache\/i3lock\/lock\.png/' \
~/.config/i3/config ~/.local/bin/rofi-power.sh

# Update ranger preview_images_method
sed -i -e '/preview_images_method ueberzug/d' \
-e 's/#set preview_images/set preview_images/' ~/.config/ranger/rc.conf
