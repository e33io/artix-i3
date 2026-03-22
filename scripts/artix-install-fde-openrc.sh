#!/usr/bin/env bash

# =============================================================================
# Artix Linux - Full Disk Encryption Install Script
# =============================================================================
# Target:   EFI/UEFI system
# Init:     OpenRC
# FS:       EXT4 (no LVM)
# Crypto:   LUKS1
# Bootloader: GRUB
#
# Partition layout:
#   /dev/sdX1  -  300 MiB  - FAT32   - EFI System Partition (/boot/efi)
#   /dev/sdX2  -  1 GiB    - EXT4    - unencrypted /boot  (single passphrase prompt)
#   /dev/sdX3  -  rest     - LUKS1   - encrypted EXT4 root (/)
#
# USAGE:
#   1. Boot from an Artix Linux ISO (base or any DE variant)
#   2. Ensure network connectivity (ping artixlinux.org)
#   3. Set the variables in the CONFIG block below
#   4. Run:  bash artix-install-fde-openrc.sh
#
# NOTES:
#   - This script assumes a single-disk install.  Adjust DISK for NVMe
#     (e.g. /dev/nvme0n1 - partitions become /dev/nvme0n1p1, p2, p3).
#   - The LUKS mapper name "cryptroot" is used throughout.  Change
#     CRYPT_NAME if you prefer something different.
#   - LUKS1 is used for compatibility.  With /boot unencrypted GRUB
#     never touches the LUKS container, so LUKS2 would also work here,
#     but LUKS1 is kept as a safe, widely-supported default.
#   - You will be prompted to type your LUKS passphrase interactively
#     when cryptsetup runs - it is NOT stored anywhere in this script.
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIG - edit these before running
# =============================================================================

DISK="/dev/sda"            # Target disk.  Use /dev/nvme0n1 for NVMe.
CRYPT_NAME="cryptroot"     # dm-crypt device name  (/dev/mapper/cryptroot)
HOSTNAME="artix"           # System hostname
TIMEZONE="America/Chicago" # tzdata path under /usr/share/zoneinfo
LOCALE="en_US.UTF-8"       # Locale (must exist in /etc/locale.gen)
KEYMAP="us"                # Console keymap
USERNAME="user"            # Non-root user to create
UCODE=""                   # CPU microcode: "intel-ucode" | "amd-ucode" | ""
                           # Leave blank to skip microcode installation.

# =============================================================================
# Derived variables - do not edit unless you know what you are doing
# =============================================================================

# Handle both /dev/sdXN and /dev/nvme0nXpN naming conventions
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    PART_EFI="${DISK}p1"
    PART_BOOT="${DISK}p2"
    PART_LUKS="${DISK}p3"
else
    PART_EFI="${DISK}1"
    PART_BOOT="${DISK}2"
    PART_LUKS="${DISK}3"
fi

CRYPT_DEV="/dev/mapper/${CRYPT_NAME}"

# =============================================================================
# Helper functions
# =============================================================================

info()  { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn()  { echo -e "\033[1;33mWARN: $*\033[0m"; }
die()   { echo -e "\033[1;31mERROR: $*\033[0m"; exit 1; }

confirm() {
    read -rp "$1 [y/N] " ans
    [[ "${ans,,}" == "y" ]] || die "Aborted by user."
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

info "Pre-flight checks"

[[ $(id -u) -eq 0 ]]        || die "Must be run as root."
[[ -b "$DISK" ]]            || die "Disk $DISK not found."
ls /sys/firmware/efi/efivars &>/dev/null \
                            || die "Not booted in UEFI mode."
ping -c1 -W3 artixlinux.org &>/dev/null \
                            || warn "No internet - make sure the mirror list is cached."

echo
echo "  Disk      : $DISK"
echo "  EFI part  : $PART_EFI"
echo "  Boot part : $PART_BOOT"
echo "  LUKS part : $PART_LUKS"
echo "  Hostname  : $HOSTNAME"
echo "  Timezone  : $TIMEZONE"
echo "  Username  : $USERNAME"
echo "  Microcode : ${UCODE:-none}"
echo
warn "ALL DATA ON $DISK WILL BE DESTROYED."
confirm "Continue?"

# =============================================================================
# STEP 0 - INSTALL REQUIRED TOOLS
# =============================================================================

info "Installing required partitioning tools"
pacman -Sy --noconfirm gptfdisk parted

# =============================================================================
# STEP 1 - PARTITION THE DISK
# =============================================================================

info "Partitioning $DISK"

# Wipe existing signatures and partition table
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"

# GPT partition table
# Partition 1: 300 MiB  - EFI System Partition  (FAT32, unencrypted)
# Partition 2: 1 GiB    - /boot                 (EXT4, unencrypted)
# Partition 3: remainder - LUKS container        (encrypted EXT4 root)
#
# With /boot on its own unencrypted partition, GRUB reads the kernel
# and initramfs without touching LUKS - eliminating the double-prompt.
# Only the kernel's encrypt hook prompts once for the root passphrase.
parted -s "$DISK" mklabel gpt
parted -s -a optimal "$DISK" mkpart "EFI"  fat32 0%      300MiB
parted -s "$DISK" set 1 esp on
parted -s -a optimal "$DISK" mkpart "BOOT" ext4  300MiB  1324MiB
parted -s -a optimal "$DISK" mkpart "ROOT" ext4  1324MiB 100%

# Verify alignment
parted -s "$DISK" align-check optimal 1
parted -s "$DISK" align-check optimal 2
parted -s "$DISK" align-check optimal 3

# Re-read partition table
partprobe "$DISK"
sleep 2   # give udev a moment to create the new block devices

info "Partition layout:"
parted -s "$DISK" print

# =============================================================================
# STEP 2 - FORMAT EFI PARTITION
# =============================================================================

info "Formatting EFI partition ($PART_EFI) as FAT32"
mkfs.fat -F32 -n "EFI" "$PART_EFI"

# =============================================================================
# STEP 2b - FORMAT /boot PARTITION
# =============================================================================

info "Formatting /boot partition ($PART_BOOT) as EXT4"
mkfs.ext4 -L "BOOT" "$PART_BOOT"

# =============================================================================
# STEP 3 - SET UP LUKS1 ENCRYPTION
# =============================================================================
# LUKS1 is used for broad compatibility.  Because GRUB reads /boot from the
# plaintext partition and never touches this LUKS container, LUKS2 would
# also work - but LUKS1 avoids any edge-case GRUB/LUKS2 issues.

info "Setting up LUKS1 encryption on $PART_LUKS"
echo
echo "You will now be prompted to create your disk encryption passphrase."
echo "Choose a strong passphrase and remember it - there is NO recovery."
echo

cryptsetup \
    --verbose \
    --type luks1 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha512 \
    luksFormat "$PART_LUKS"

info "Opening LUKS container as /dev/mapper/$CRYPT_NAME"
cryptsetup luksOpen "$PART_LUKS" "$CRYPT_NAME"

# =============================================================================
# STEP 4 - FORMAT THE ROOT FILESYSTEM
# =============================================================================

info "Formatting root filesystem ($CRYPT_DEV) as EXT4"
mkfs.ext4 -L "ROOT" "$CRYPT_DEV"

# =============================================================================
# STEP 5 - MOUNT FILESYSTEMS
# =============================================================================

info "Mounting filesystems"
mount "$CRYPT_DEV" /mnt

mkdir -p /mnt/boot
mount "$PART_BOOT" /mnt/boot

mkdir -p /mnt/boot/efi
mount "$PART_EFI" /mnt/boot/efi

# Verify layout
echo
lsblk -f "$DISK"

# =============================================================================
# STEP 6 - BOOTSTRAP BASE SYSTEM
# =============================================================================

info "Installing base system with basestrap"

BASESTRAP_PKGS=(
    base
    base-devel
    openrc
    elogind-openrc
    linux
    linux-headers
    linux-firmware
    cryptsetup
    cryptsetup-openrc
    device-mapper
    device-mapper-openrc
    grub
    efibootmgr
    dosfstools
    dbus
    dbus-openrc
    networkmanager
    networkmanager-openrc
    dhcpcd
    dhcpcd-openrc
    vim
    nano
    sudo
)

# Add CPU microcode if specified
[[ -n "$UCODE" ]] && BASESTRAP_PKGS+=("$UCODE")

basestrap /mnt "${BASESTRAP_PKGS[@]}"

# =============================================================================
# STEP 7a - GENERATE FSTAB
# =============================================================================

info "Generating /etc/fstab"
fstabgen -U /mnt >> /mnt/etc/fstab

echo
echo "Generated fstab:"
cat /mnt/etc/fstab

# =============================================================================
# STEP 7b - CREATE SWAP FILE
# =============================================================================

info "Creating 2GB swap file"
fallocate -l 2G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
printf "\n# swap file\n/swapfile swap swap defaults 0 0\n" >> /mnt/etc/fstab
echo "vm.swappiness=5" >> /mnt/etc/sysctl.conf

# =============================================================================
# STEP 8 - CHROOT CONFIGURATION
# =============================================================================
# Everything below runs inside artix-chroot via a heredoc.
# Variables are expanded NOW (on the live ISO), not inside the chroot,
# so all $VAR references resolve correctly before being passed in.

info "Entering chroot for system configuration"

# Capture the LUKS partition UUID now, before chroot
LUKS_UUID=$(blkid -s UUID -o value "$PART_LUKS")
ROOT_UUID=$(blkid -s UUID -o value "$CRYPT_DEV")

echo "  LUKS UUID : $LUKS_UUID"
echo "  Root UUID : $ROOT_UUID"

artix-chroot /mnt /bin/bash <<CHROOT
set -euo pipefail

# ------------------------------------------------------------------
# 8a. Timezone & hardware clock
# ------------------------------------------------------------------
echo "==> Setting timezone: ${TIMEZONE}"
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# ------------------------------------------------------------------
# 8b. Locale
# ------------------------------------------------------------------
echo "==> Generating locale: ${LOCALE}"
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "LC_COLLATE=C"   >> /etc/locale.conf

# ------------------------------------------------------------------
# 8c. Console keymap
# ------------------------------------------------------------------
echo "==> Setting console keymap: ${KEYMAP}"
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# ------------------------------------------------------------------
# 8d. Hostname
# ------------------------------------------------------------------
echo "==> Setting hostname: ${HOSTNAME}"
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain  ${HOSTNAME}
EOF

# ------------------------------------------------------------------
# 8e. mkinitcpio - add encrypt hook (no lvm2 since we skip LVM)
# ------------------------------------------------------------------
echo "==> Configuring mkinitcpio"
# HOOKS order: base udev autodetect modconf kms keyboard keymap
#              consolefont block encrypt filesystems fsck
# "encrypt" must come AFTER "block" and BEFORE "filesystems"
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' \
    /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio --preset linux

# ------------------------------------------------------------------
# 8f. GRUB - set kernel parameters (no cryptodisk needed)
# ------------------------------------------------------------------
echo "==> Configuring GRUB"

# GRUB_ENABLE_CRYPTODISK is NOT needed - GRUB reads /boot (kernel,
# initramfs, grub.cfg) from the plaintext $PART_BOOT partition.
# The kernel's encrypt hook handles unlocking root via the cmdline.

# Set kernel parameters:
#   cryptdevice=UUID=<luks-uuid>:<mapper-name>  - LUKS device to unlock
#   root=/dev/mapper/<mapper-name>               - decrypted root location
#   rw                                           - mount root read-write
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${LUKS_UUID}:${CRYPT_NAME} root=${CRYPT_DEV} rw\"|" \
    /etc/default/grub

# Install GRUB to EFI - efi-directory points to the EFI partition
# which is mounted at /boot/efi
echo "==> Installing GRUB (EFI)"
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=artix \
    --recheck

# Generate GRUB config - grub.cfg lands in /boot/grub/ (on plain /boot)
grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------------
# 8g. Enable OpenRC services
# ------------------------------------------------------------------
echo "==> Enabling OpenRC services"
# device-mapper and cryptsetup run at boot level to ensure the LUKS
# container is available before the filesystem is mounted.
# dbus must be at default level before NetworkManager.
rc-update add device-mapper boot
rc-update add dmcrypt boot
rc-update add dbus default
rc-update add NetworkManager default
rc-update add dhcpcd default

echo "==> Chroot configuration complete."
CHROOT

# =============================================================================
# STEP 8h - SET PASSWORDS AND CREATE USER (outside heredoc for tty access)
# =============================================================================
# passwd requires an interactive tty - it cannot run inside a heredoc.
# These steps run as separate artix-chroot invocations after the main
# configuration heredoc has closed, restoring proper stdin from the terminal.

info "Setting root password"
artix-chroot /mnt passwd

info "Creating user: $USERNAME"
artix-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"

info "Setting password for $USERNAME"
artix-chroot /mnt passwd "$USERNAME"

# Allow wheel group to use sudo
artix-chroot /mnt sed -i \
    's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' \
    /etc/sudoers

# =============================================================================
# STEP 9 - CLEANUP AND REBOOT
# =============================================================================

info "Unmounting filesystems"
umount -R /mnt
cryptsetup luksClose "$CRYPT_NAME"

echo
echo "============================================================"
echo "  Installation complete."
echo ""
echo "  On first boot you will see ONE passphrase prompt from the"
echo "  kernel's encrypt hook to unlock the root partition."
echo "  GRUB reads /boot (kernel + initramfs) unencrypted, so it"
echo "  never needs to prompt."
echo ""
echo "  POST-INSTALL CHECKLIST:"
echo "   - Set up Wi-Fi if needed (nmtui / nmcli)"
echo "   - Install a display server / DE if desired"
echo "   - Configure pacman mirrors: /etc/pacman.d/mirrorlist"
echo "   - Add Arch repos to pacman.conf if you need Arch packages"
echo "============================================================"
echo
read -rp "Reboot now? [y/N] " reboot_now
[[ "${reboot_now,,}" == "y" ]] && reboot
