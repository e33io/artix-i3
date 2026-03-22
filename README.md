# Artix + i3

![i3 screenshot](https://i.e33.io/img0/i3-screenshot_2026-03-22.png)

### Features:
- Custom [i3](https://i3wm.org) installation for [Artix](https://github.com/e33io/artix-i3/blob/main/scripts/install-i3.sh) (OpenRC)
- Base set of apps for a ready-to-use desktop session
- Options during installation for configuring:
	- HiDPI or standard HD display scaling
	- Device-specific optimizations for desktop, laptop or VM devices
- [Polybar](https://github.com/polybar/polybar) for system bar and app tray
- 18 system theme options (15 dark and 3 light)
- 3 Rofi style options (dmenu, floating and panel)
- Inter and [SovranMono](https://github.com/e33io/sovran-fonts) fonts
- Systemd-free

### Installation:
```bash
# clone repo
git clone https://github.com/e33io/artix-i3

# change directory
cd artix-i3

# run script
sh install.sh
```

### Utilities:
```bash
# change wallpaper and i3lock image
set-bg /path/to/image

# change system theme
set-theming

# change Rofi style
rofi-style

# select wifi connection
wifi
```

&nbsp;

## i3 Keybindings

```
Modifier keys:

Mod4      Windows (Super) key
Mod1      Alt key
ctrl      Control key
Shift     Shift key
Return    Enter key
space     Space bar
Left      Left arrow key
Right     Right arrow key
Up        Up arrow key
Down      Down arrow key
equal     Equal key
minus     Minus key
Print     PrtSc (Print Screen) key
button1   Left mouse button
button3   Right mouse button
```
```
Custom keybindings:  $super = Mod4  $alt = Mod1

$super+d              Program launcher (app menu)
$super+Return         Launch terminal
$super+Shift+Return   Launch file manager
$super+b              Launch web browser
$super+1              Switch to workspace 1
$super+2              Switch to workspace 2
$super+3              Switch to workspace 3
$super+4              Switch to workspace 4
$super+5              Switch to workspace 5
$super+6              Switch to workspace 6
$super+7              Switch to workspace 7
$super+8              Switch to workspace 8
$super+9              Switch to workspace 9
$super+0              Switch to workspace 10
ctrl+$alt+Right       Switch to next workspace
ctrl+$alt+Left        Switch to previous workspace
$super+u              Switch to workspace with urgent window
$super+Shift+1        Move active window to workspace 1
$super+Shift+2        Move active window to workspace 2
$super+Shift+3        Move active window to workspace 3
$super+Shift+4        Move active window to workspace 4
$super+Shift+5        Move active window to workspace 5
$super+Shift+6        Move active window to workspace 6
$super+Shift+7        Move active window to workspace 7
$super+Shift+8        Move active window to workspace 8
$super+Shift+9        Move active window to workspace 9
$super+Shift+0        Move active window to workspace 10
$super+h              Split container horizontal for next window
$super+v              Split container vertical for next window
$super+Right          Change active window focus right
$super+Left           Change active window focus left
$super+Up             Change active window focus up
$super+Down           Change active window focus down
$super+ctrl+Right     Move active window right
$super+ctrl+Left      Move active window left
$super+ctrl+Up        Move active window up
$super+ctrl+Down      Move active window down
ctrl+Shift+Right      Resize (grow) active window wider
ctrl+Shift+Left       Resize (shrink) active window narrower
ctrl+Shift+Up         Resize (shrink) active window shorter
ctrl+Shift+Down       Resize (grow) active window taller
$super+Shift+space    Toggle active window floating
$super+button1        Move active floating window
$super+button3        Resize active floating window, non-proportionally
$super+Shift+button3  Resize active floating window, proportionally
$super+Shift+f        Toggle active window fullscreen
$super+equal          Resize (increase) window gaps
$super+minus          Resize (decrease) window gaps
$super+o              Show list of open windows
$super+Shift+q        Close active window
$super+e              Toggle container split direction and/or change layout to split
$super+w              Change container layout to tabbed
$super+s              Change container layout to stacking
Print                 Screenshot entire desktop
Shift+Print           Screenshot selected area
$super+Print          Screenshot active window
$super+ctrl+equal     Disable dpms to keep session awake (like Caffeine)
$super+ctrl+minus     Re-enable dpms to resume screen blanking and locking
$super+x              Lock screen
$super+p              Power menu (lock, logout, reboot, shutdown)
```

View the [~/.config/i3/config](https://github.com/e33io/dots/blob/main/home/.config/i3/config) file to see all the configured keybindings that aren’t indicated in the box above

&nbsp;
