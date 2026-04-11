#!/usr/bin/env bash

# =============================================================================
# Modify Arch configs for use with Artix Linux (OpenRC)
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/mod-configs.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Update i3 startup.conf file
awk '
# Insert pipewire block before XDG autostart
/^# Start XDG autostart/ {
    print "# Start pipewire and wireplumber"
    print "$exec pipewire"
    print "$exec wireplumber"
    print "$exec pipewire-pulse"
    print ""
    print
    next
}
# Replace xss-lock comment
/^# Start xss-lock/ {
    print "# Start xautolock with i3lock as locker"
    next
}
# Replace xss-lock command
/^\$exec xss-lock/ {
    print "$exec xautolock -time 5 -locker \"i3lock -i ~/.cache/i3lock/lock.png\""
    print ""
    next
}
# Add DPMS comment
/^\$exec sleep 1 && xset dpms/ {
    print "# Set monitor DPMS timeout"
    print
    next
}
{
    print
}
' ~/dots/home/.config/i3/startup.conf > ~/.config/i3/startup.conf

# Update rofi-power.sh file
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

# Add aliases for reboot and power off
printf "%s\n" "" "# Reboot and power off" "alias reboot='loginctl reboot'" \
"alias poweroff='loginctl poweroff'" | tee -a ~/.bashrc > /dev/null

# Set default mute and default volume level
mkdir -p ~/.config/autostart
printf "%s\n" "[Desktop Entry]" "Version=1.0" "Type=Application" \
"Name=audio-default" "Comment=set default mute and default volume level" \
"Exec=sh -c 'sleep 1; pactl set-sink-mute @DEFAULT_SINK@ false; sleep 6; pactl set-sink-volume @DEFAULT_SINK@ 20%'" \
"Icon=xfce4-mixer" "StartupNotify=false" "Terminal=false" "NoDisplay=true" \
"Hidden=false" > ~/.config/autostart/audio-default.desktop

# Update ranger preview_images_method
sed -i -e '/preview_images_method ueberzug/d' \
-e 's/#set preview_images/set preview_images/' ~/.config/ranger/rc.conf

# Remove unneeded commands
sed -i '/xssproxy/d' ~/.profile
