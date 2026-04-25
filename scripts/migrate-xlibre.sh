#!/usr/bin/env bash

# =============================================================================
# Replace xorg-server and xf86 drivers with XLibre on an existing Artix install
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/migrate-xlibre.sh
# -----------------------------------------------------------------------------
# Use this script at your own risk, it will overwrite existing files!
# =============================================================================

set -e

# Intel GPU generations by PCI device ID prefix:
# Broadwell (0x1600+) and newer use intel-media-driver (iHD)
# Haswell and older use libva-intel-driver (i965)
intel_va_driver() {
    local device_id
    device_id=$(lspci -n 2>/dev/null \
        | grep -iE '0300:' \
        | awk '{print $3}' \
        | grep '8086' \
        | head -1 \
        | cut -d: -f2)

    if [[ -z "$device_id" ]]; then
        echo "intel-media-driver"
        return
    fi

    local id_dec
    id_dec=$(printf '%d' "0x${device_id}" 2>/dev/null || echo 0)

    # Broadwell device IDs start at 0x1600; anything below is Haswell or older
    if (( id_dec >= 0x1600 )); then
        echo "intel-media-driver"
    else
        echo "libva-intel-driver"
    fi
}

# --- GPU detection ---
detect_video_drivers() {
    local drivers=("xlibre-video-vesa" "xlibre-video-fbdev")
    local extra=()

    while IFS= read -r line; do
        case "${line,,}" in
            *nvidia*)
                echo "  [GPU] NVIDIA detected" >&2
                drivers+=("xlibre-video-nouveau")
                ;;
            *amd*|*radeon*)
                echo "  [GPU] AMD detected" >&2
                drivers+=("xlibre-video-amdgpu" "xlibre-video-ati")
                extra+=("mesa" "vulkan-radeon")
                ;;
            *intel*)
                echo "  [GPU] Intel detected" >&2
                drivers+=("xlibre-video-intel")
                local va_driver
                va_driver=$(intel_va_driver)
                echo "  [GPU] Intel VA-API driver: ${va_driver}" >&2
                extra+=("${va_driver}" "vulkan-intel")
                ;;
            *vmware*|*vmsvga*)
                echo "  [GPU] VMware detected" >&2
                drivers+=("xlibre-video-vmware")
                ;;
            *virtualbox*)
                echo "  [GPU] VirtualBox detected" >&2
                drivers+=("xlibre-video-vboxvideo")
                ;;
            *qxl*)
                echo "  [GPU] QXL/QEMU detected" >&2
                drivers+=("xlibre-video-qxl")
                ;;
            *virtio*)
                echo "  [GPU] VirtIO GPU detected (modesetting driver - no extra package needed)" >&2
                drivers+=("xlibre-video-dummy")
                ;;
            *ast*)
                echo "  [GPU] ASPEED detected" >&2
                drivers+=("xlibre-video-ast")
                ;;
        esac
    done < <(lspci 2>/dev/null | grep -i -E 'vga|3d|display')

    local all=("${drivers[@]}" "${extra[@]}")
    local unique=()
    for d in "${all[@]}"; do
        [[ " ${unique[*]} " == *" $d "* ]] || unique+=("$d")
    done

    echo "${unique[@]}"
}

# --- Find installed xorg-server and xf86 packages to remove ---
find_xorg_packages() {
    pacman -Q 2>/dev/null \
        | awk '{print $1}' \
        | grep -E '^(xorg-server|xorg-server-common|xorg-server-devel|xorg-server-xvfb|xf86-)'
}

# --- Main ---
echo "Detecting GPU..."
mapfile -t video_drivers < <(detect_video_drivers | tr ' ' '\n')

if [[ ${#video_drivers[@]} -eq 0 ]]; then
    echo "  [!] No GPU detected, falling back to vesa+fbdev only"
    video_drivers=("xlibre-video-vesa" "xlibre-video-fbdev")
fi

echo "Video/GPU packages to install: ${video_drivers[*]}"
echo

# --- Find xorg packages to remove ---
echo "Scanning for installed xorg-server and xf86 packages..."
mapfile -t xorg_pkgs < <(find_xorg_packages)

if [[ ${#xorg_pkgs[@]} -eq 0 ]]; then
    echo "  [!] No xorg-server or xf86 packages found - nothing to remove."
else
    echo "  Packages to remove:"
    printf '    %s\n' "${xorg_pkgs[@]}"
    echo
    echo "  These will be force-removed with -Rdd to avoid dependency complaints."
    read -rp "Proceed with removal? [y/N] " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Aborted."
        exit 1
    fi
    sudo pacman -Rdd --noconfirm "${xorg_pkgs[@]}"
    echo "  Done removing xorg packages."
fi

echo

# --- Install XLibre ---
packages=(
    xlibre-xserver
    xlibre-xserver-common
    xlibre-input-libinput
    xlibre-input-evdev
    "${video_drivers[@]}"
    xorg-apps
    xorg-xinit
)

echo "Installing XLibre packages:"
printf '    %s\n' "${packages[@]}"
echo

sudo pacman -S --needed "${packages[@]}"

echo
echo "Verifying installation..."
echo "  Installed xlibre packages:"
pacman -Q | grep 'xlibre-'
echo
echo "  Remaining xorg-server/xf86 packages (should be empty):"
find_xorg_packages || echo "  None - all clear."

echo
echo "Migration complete. Reboot or restart your display server."
