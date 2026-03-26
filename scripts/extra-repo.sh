#!/usr/bin/env bash

# =============================================================================
# Add Arch [extra] repo to Artix Linux
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/extra-repo.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

if grep -q "^\[extra\]" /etc/pacman.conf; then
    echo "Arch [extra] repo already present in pacman.conf -- skipping."
else
    echo "========================================================================"
    echo "Add Arch [extra] repo"
    echo "========================================================================"

    # Install artix-archlinux-support
    sudo pacman -S --noconfirm --needed artix-archlinux-support
    # Append after the last Artix repo block
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

# Arch Linux repos must remain AFTER Artix repos so Artix takes precedence
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    # Populate Arch Linux keyring
    sudo pacman-key --populate archlinux
    # Sync package databases
    sudo pacman -Sy
    echo "Arch [extra] repo is now enabled."
fi
