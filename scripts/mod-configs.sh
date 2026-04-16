#!/usr/bin/env bash

# =============================================================================
# Modify Arch configs for use with Artix Linux (OpenRC)
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/mod-configs.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Remove incompatible commands
sed -i '/xss-lock/d' ~/.config/i3/startup.conf
sed -i '/xssproxy/d' ~/.profile

# Add startup commands for pipewire
printf "%s\n" "" "pgrep -x pipewire >/dev/null || pipewire &" \
"pgrep -x pipewire-pulse >/dev/null || pipewire-pulse &" \
"pgrep -x wireplumber >/dev/null || wireplumber &" \
| tee -a ~/.xprofile > /dev/null

# Add comment for DPMS
sed -i '/xset dpms/i\
# Set monitor DPMS timeout
' ~/.config/i3/startup.conf

# Add startup commands for xautolock
printf "%s\n" "" "# Start xautolock with i3lock as locker" \
"\$exec xautolock -time 5 -locker \"i3lock -i ~/.cache/i3lock/lock.png\"" \
| tee -a ~/.config/i3/startup.conf > /dev/null

# Replace loginctl lock-session with i3lock
sed -i 's/loginctl lock-session/i3lock -i ~\/\.cache\/i3lock\/lock\.png/' \
~/.config/i3/config

# Add bash aliases for reboot and power off
printf "%s\n" "" "# Reboot and power off" "alias reboot='loginctl reboot'" \
"alias poweroff='loginctl poweroff'" | tee -a ~/.bashrc > /dev/null

# Replace systemctl with loginctl and remove "Logout" option
awk '
# Remove "Logout" from options array
/^[[:space:]]*"Logout"/ {
    next
}
# Rewrite entire case block
/^case[[:space:]]+\$choice[[:space:]]+in/ {
    print "case $choice in"
    print "    \"Lock\")"
    print "        i3lock -i ~/.cache/i3lock/lock.png"
    print "    ;;"
    print "    \"Reboot\")"
    print "        loginctl reboot"
    print "    ;;"
    print "    \"Shutdown\")"
    print "        loginctl poweroff"
    print "    ;;"
    print "    *)"
    print "        exit 0"
    print "    ;;"
    print "esac"

    in_case=1
    next
}
# Skip original case block entirely
in_case {
    if (/^esac/) {
        in_case=0
    }
    next
}
{
    print
}
' ~/dots/home/.local/bin/rofi-power.sh > ~/.local/bin/rofi-power.sh

# Update ranger preview_images_method
sed -i -e '/preview_images_method ueberzug/d' \
-e 's/#set preview_images/set preview_images/' ~/.config/ranger/rc.conf
