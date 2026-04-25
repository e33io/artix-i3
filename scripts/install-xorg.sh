#!/usr/bin/env bash

# =============================================================================
# Autodetect GPU and install Xorg for Artix Linux
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/install-xorg.sh
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
    local drivers=("xf86-video-vesa" "xf86-video-fbdev")
    local extra=()

    while IFS= read -r line; do
        case "${line,,}" in
            *nvidia*)
                echo "  [GPU] NVIDIA detected" >&2
                drivers+=("xf86-video-nouveau")
                ;;
            *amd*|*radeon*)
                echo "  [GPU] AMD detected" >&2
                drivers+=("xf86-video-amdgpu" "xf86-video-ati")
                extra+=("mesa" "vulkan-radeon")
                ;;
            *intel*)
                echo "  [GPU] Intel detected" >&2
                drivers+=("xf86-video-intel")
                local va_driver
                va_driver=$(intel_va_driver)
                echo "  [GPU] Intel VA-API driver: ${va_driver}" >&2
                extra+=("${va_driver}" "vulkan-intel")
                ;;
            *vmware*|*vmsvga*)
                echo "  [GPU] VMware detected" >&2
                drivers+=("xf86-video-vmware")
                ;;
            *virtualbox*)
                echo "  [GPU] VirtualBox detected" >&2
                drivers+=("xf86-video-vboxvideo")
                ;;
            *qxl*)
                echo "  [GPU] QXL/QEMU detected" >&2
                drivers+=("xf86-video-qxl")
                ;;
            *virtio*)
                echo "  [GPU] VirtIO GPU detected (modesetting driver - no extra package needed)" >&2
                drivers+=("xf86-video-dummy")
                ;;
            *ast*)
                echo "  [GPU] ASPEED detected" >&2
                drivers+=("xf86-video-ast")
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

# --- Main ---
echo "Detecting GPU..."
mapfile -t video_drivers < <(detect_video_drivers | tr ' ' '\n')

if [[ ${#video_drivers[@]} -eq 0 ]]; then
    echo "  [!] No GPU detected, falling back to vesa+fbdev only"
    video_drivers=("xf86-video-vesa" "xf86-video-fbdev")
fi

echo "Video/GPU packages to install: ${video_drivers[*]}"
echo

packages=(
    xorg-server
    xorg-server-common
    xf86-input-libinput
    xf86-input-evdev
    "${video_drivers[@]}"
    xorg-apps
    xorg-xinit
)

echo "Installing packages:"
printf '    %s\n' "${packages[@]}"
echo

sudo pacman -S --noconfirm --needed "${packages[@]}"

echo
echo "Done."
