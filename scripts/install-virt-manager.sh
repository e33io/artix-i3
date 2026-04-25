#!/usr/bin/env bash

# =============================================================================
# Artix Linux (OpenRC) - QEMU / libvirt / virt-manager Setup Script
# URL: https://github.com/e33io/artix-i3/blob/main/scripts/install-virt-manager.sh
# =============================================================================
# Usage: chmod +x setup-virt-openrc.sh && sudo ./setup-virt-openrc.sh
# =============================================================================

set -euo pipefail

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${NC} $*" >&2; exit 1; }

# -- Root check ---------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    error "Please run this script as root (sudo ./setup-virt-openrc.sh)"
fi

# -- Detect the real (non-root) user ------------------------------------------
REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" ]]; then
    error "Could not detect the invoking user. Run with sudo, not as root directly."
fi
info "Detected user: ${BOLD}${REAL_USER}${NC}"

# -- Packages -----------------------------------------------------------------
PACKAGES=(
    qemu-full
    virt-manager
    libvirt
    libvirt-openrc
    dnsmasq
    dmidecode
    edk2-ovmf
    openbsd-netcat   # required for remote QEMU connections
)

# =============================================================================
# STEP 1 - Install packages
# =============================================================================
echo
info "Step 1/4 - Installing packages..."
pacman -Syu --noconfirm --needed "${PACKAGES[@]}" \
    && success "Packages installed." \
    || error "pacman failed. Check your internet connection and mirrors."

# =============================================================================
# STEP 2 - Configure libvirt
# =============================================================================
echo
info "Step 2/4 - Configuring libvirt..."

LIBVIRT_CONF="/etc/libvirt/libvirtd.conf"

if [[ ! -f "$LIBVIRT_CONF" ]]; then
    error "libvirtd.conf not found at $LIBVIRT_CONF - was libvirt-openrc installed?"
fi

# Back up the original config
cp "$LIBVIRT_CONF" "${LIBVIRT_CONF}.bak"
info "Backed up original config to ${LIBVIRT_CONF}.bak"

# Uncomment / set required socket permissions
sed -i \
    -e 's|^#*unix_sock_group\s*=.*|unix_sock_group = "libvirt"|' \
    -e 's|^#*unix_sock_ro_perms\s*=.*|unix_sock_ro_perms = "0777"|' \
    -e 's|^#*unix_sock_rw_perms\s*=.*|unix_sock_rw_perms = "0770"|' \
    "$LIBVIRT_CONF"

success "libvirtd.conf updated."

# Enable the default NAT network on startup
QEMU_CONF="/etc/libvirt/qemu.conf"
if [[ -f "$QEMU_CONF" ]]; then
    # Use the correct UEFI firmware path for edk2-ovmf on Artix/Arch
    if ! grep -q "nvram" "$QEMU_CONF"; then
        cat >> "$QEMU_CONF" <<'EOF'

# OVMF firmware paths (added by setup script)
nvram = [
    "/usr/share/edk2/x64/OVMF_CODE.fd:/usr/share/edk2/x64/OVMF_VARS.fd",
    "/usr/share/edk2/x64/OVMF_CODE.secboot.fd:/usr/share/edk2/x64/OVMF_VARS.fd"
]
EOF
        success "OVMF firmware paths added to qemu.conf."
    else
        warn "nvram entry already present in qemu.conf - skipping."
    fi
fi

# =============================================================================
# STEP 3 - Add user to required groups
# =============================================================================
echo
info "Step 3/4 - Adding ${REAL_USER} to libvirt and kvm groups..."

for group in libvirt kvm; do
    if getent group "$group" > /dev/null 2>&1; then
        usermod -aG "$group" "$REAL_USER"
        success "Added ${REAL_USER} to group: ${group}"
    else
        warn "Group '${group}' does not exist - skipping."
    fi
done

# =============================================================================
# STEP 4 - Enable and start libvirtd via OpenRC
# =============================================================================
echo
info "Step 4/5 - Enabling libvirtd with OpenRC..."

rc-update add libvirtd default \
    && success "libvirtd added to default runlevel." \
    || warn "rc-update failed - service may already be added."

rc-service libvirtd start \
    && success "libvirtd started." \
    || warn "Failed to start libvirtd. Check: rc-service libvirtd status"

# Also enable virtlogd (needed for guest console logging)
if rc-update show | grep -q virtlogd; then
    warn "virtlogd already in runlevel - skipping."
else
    rc-update add virtlogd default && success "virtlogd added to default runlevel." || true
fi

rc-service virtlogd start 2>/dev/null && success "virtlogd started." || true

# =============================================================================
# STEP 5 - Set up the default NAT network
# =============================================================================
echo
info "Step 5/5 - Configuring default NAT network..."

DEFAULT_NET_XML="/usr/share/libvirt/networks/default.xml"

# Give libvirtd a moment to be fully ready for virsh commands
sleep 2

# Check if the default network already exists
if virsh net-info default &>/dev/null; then
    info "Default network already defined."
else
    # Define it from the shipped default XML
    if [[ -f "$DEFAULT_NET_XML" ]]; then
        virsh net-define "$DEFAULT_NET_XML" \
            && success "Default network defined from $DEFAULT_NET_XML." \
            || error "Failed to define default network."
    else
        # Fall back to an inline definition if the file is missing
        warn "$DEFAULT_NET_XML not found - using inline definition."
        virsh net-define /dev/stdin <<'NETXML'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
NETXML
        success "Default network defined from inline definition."
    fi
fi

# Clear any stale virbr0 bridge that might block net-start
if ip link show virbr0 &>/dev/null; then
    NET_STATE=$(virsh net-info default 2>/dev/null | awk '/^Active:/{print $2}')
    if [[ "$NET_STATE" != "yes" ]]; then
        warn "Stale virbr0 bridge detected - cleaning up..."
        ip link set virbr0 down 2>/dev/null || true
        ip link delete virbr0 2>/dev/null || true
        success "Stale virbr0 removed."
    fi
fi

# Start the network if not already active
NET_STATE=$(virsh net-info default 2>/dev/null | awk '/^Active:/{print $2}')
if [[ "$NET_STATE" == "yes" ]]; then
    warn "Default network is already active - skipping net-start."
else
    virsh net-start default \
        && success "Default network started." \
        || warn "Could not start default network. Try: sudo virsh net-start default"
fi

# Enable autostart so it comes up after every libvirtd restart
AUTOSTART=$(virsh net-info default 2>/dev/null | awk '/^Autostart:/{print $2}')
if [[ "$AUTOSTART" == "yes" ]]; then
    warn "Default network autostart already enabled - skipping."
else
    virsh net-autostart default \
        && success "Default network set to autostart." \
        || warn "Could not set autostart. Try: sudo virsh net-autostart default"
fi

# Confirm final state
echo
info "Network status:"
virsh net-list --all

# =============================================================================
# Done
# =============================================================================
echo
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  Setup complete!${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  1. ${YELLOW}Log out and back in${NC} for group membership to take effect."
echo -e "  2. Launch ${BOLD}virt-manager${NC} as ${REAL_USER} (no sudo needed)."
echo -e "  3. The default NAT network (virbr0) is active and set to autostart."
echo
