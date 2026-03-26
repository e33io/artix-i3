#!/usr/bin/env bash

# =============================================================================
# Add Arch [extra] repo to Artix Linux
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/extra-repo.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

if ! grep -q "^\[extra\]" /etc/pacman.conf; then
    echo "========================================================================"
    echo "Add Arch [extra] repo"
    echo "========================================================================"

    sudo pacman -S --noconfirm --needed artix-archlinux-support
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

# Arch Linux repos must remain AFTER Artix repos
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    sudo pacman-key --populate archlinux
    sudo pacman -Sy
fi
