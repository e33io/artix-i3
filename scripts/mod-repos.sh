#!/usr/bin/env bash

# =============================================================================
# Modify Artix Linux Repo List
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/mod-repos.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

# Install artix-archlinux-support
sudo pacman -S --noconfirm --needed artix-archlinux-support

# Update pacman.conf file
sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

# Arch Linux repos must remain AFTER Artix repos
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF

# Update pacman keys and sync repo cache
sudo pacman-key --populate archlinux
sudo pacman -Sy
