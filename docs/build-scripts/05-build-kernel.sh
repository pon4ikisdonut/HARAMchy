#!/bin/bash
# ============================================
# HARAMchy Linux - Kernel Build Script
# ============================================
# Builds and installs the Linux kernel
# ============================================

set -euo pipefail

# ============================================
# Configuration
# ============================================

KERNEL_VERSION="6.6"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
BUILD_DIR="/home/lfs/build"
LFS_ROOT="/home/lfs/lfs-root"
LOG_FILE="/home/lfs/kernel-build.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
TEAL='\033[0;36m'
NC='\033[0m'

log()      { echo -e "${TEAL}[KERNEL]${NC} $1" | tee -a "$LOG_FILE"; }
success()  { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
warn()     { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error()    { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# ============================================
# Prerequisites Check
# ============================================

check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v gcc &>/dev/null; then
        error "gcc not found. Install build essentials first."
    fi

    if ! command -v make &>/dev/null; then
        error "make not found"
    fi

    if [ ! -d "$LFS_ROOT" ]; then
        error "LFS root not found at $LFS_ROOT"
    fi

    success "Prerequisites OK"
}

# ============================================
# Download & Extract Kernel
# ============================================

download_kernel() {
    log "Downloading Linux ${KERNEL_VERSION}..."

    mkdir -p "$BUILD_DIR"

    local tarball="$BUILD_DIR/linux-${KERNEL_VERSION}.tar.xz"

    if [ ! -f "$tarball" ]; then
        wget -q --show-progress -O "$tarball" "$KERNEL_URL" \
            >> "$LOG_FILE" 2>&1 || error "Failed to download kernel"
    fi

    log "Extracting kernel source..."
    tar -xf "$tarball" -C "$BUILD_DIR" \
        >> "$LOG_FILE" 2>&1 || error "Failed to extract kernel"

    success "Kernel source ready"
}

# ============================================
# Configure Kernel
# ============================================

configure_kernel() {
    log "Configuring kernel..."

    cd "$BUILD_DIR/linux-${KERNEL_VERSION}"

    make mrproper >> "$LOG_FILE" 2>&1

    if [ -f "$LFS_ROOT/boot/config-"* ]; then
        cp "$LFS_ROOT/boot/config-"* .config
        make olddefconfig >> "$LOG_FILE" 2>&1
    else
        make defconfig >> "$LOG_FILE" 2>&1
    fi

    # Enable required options
    log "Enabling required kernel options..."

    scripts/config --enable CONFIG_VIRTIO_PCI
    scripts/config --enable CONFIG_VIRTIO_BLK
    scripts/config --enable CONFIG_VIRTIO_NET
    scripts/config --enable CONFIG_VIRTIO
    scripts/config --enable CONFIG_VIRTIO_MMIO

    scripts/config --enable CONFIG_ATA
    scripts/config --enable CONFIG_ATA_PIIX
    scripts/config --enable CONFIG_SATA_AHCI
    scripts/config --enable CONFIG_BLK_DEV_NVME

    scripts/config --enable CONFIG_USB_STORAGE
    scripts/config --enable CONFIG_USB_XHCI_HCD
    scripts/config --enable CONFIG_USB_EHCI_HCD
    scripts/config --enable CONFIG_USB_OHCI_HCD

    scripts/config --enable CONFIG_NET_VENDOR_INTEL
    scripts/config --enable CONFIG_E1000
    scripts/config --enable CONFIG_E1000E

    scripts/config --enable CONFIG_EXT4_FS
    scripts/config --enable CONFIG_EXT4_FS_POSIX_ACL
    scripts/config --enable CONFIG_EXT4_FS_SECURITY

    scripts/config --enable CONFIG_TMPFS
    scripts/config --enable CONFIG_TMPFS_POSIX_ACL
    scripts/config --enable CONFIG_TMPFS_XATTR

    scripts/config --enable CONFIG_SQUASHFS
    scripts/config --enable CONFIG_SQUASHFS_ZSTD
    scripts/config --enable CONFIG_SQUASHFS_XATTR

    scripts/config --enable CONFIG_SQUASHFS_LZO
    scripts/config --enable CONFIG_SQUASHFS_ZLIB

    scripts/config --enable CONFIG_OVERLAY_FS

    scripts/config --enable CONFIG_HARAM_GUARD

    scripts/config --enable CONFIG_SECURITY
    scripts/config --enable CONFIG_SECURITY_APPARMOR
    scripts/config --module CONFIG_SECURITY_APPARMOR

    scripts/config --disable CONFIG_DEBUG_INFO

    scripts/config --enable CONFIG_LOCALVERSION
    scripts/config --set-str CONFIG_LOCALVERSION "-haramchy"

    scripts/config --enable CONFIG_SYSVIPC
    scripts/config --enable CONFIG_POSIX_MQUEUE
    scripts/config --enable CONFIG_AUDIT

    scripts/config --enable CONFIG_NLS_CODEPAGE_437
    scripts/config --enable CONFIG_NLS_ISO8859_1
    scripts/config --enable CONFIG_NLS_UTF8

    scripts/config --enable CONFIG_BTRFS_FS
    scripts/config --module CONFIG_BTRFS_FS

    scripts/config --enable CONFIG_F2FS_FS
    scripts/config --module CONFIG_F2FS_FS

    scripts/config --enable CONFIG_XFS_FS
    scripts/config --module CONFIG_XFS_FS

    scripts/config --enable CONFIG_CRYPTO_AES
    scripts/config --enable CONFIG_CRYPTO_SHA256
    scripts/config --enable CONFIG_CRYPTO_SHA512
    scripts/config --enable CONFIG_CRYPTO_BLAKE2B

    scripts/config --enable CONFIG_LZ4_COMPRESS
    scripts/config --enable CONFIG_ZSTD_COMPRESS

    scripts/config --enable CONFIG_MODULES
    scripts/config --enable CONFIG_MODULE_UNLOAD
    scripts/config --enable CONFIG_MODULE_FORCE_UNLOAD

    make olddefconfig >> "$LOG_FILE" 2>&1

    success "Kernel configured"
}

# ============================================
# Build Kernel
# ============================================

build_kernel() {
    log "Building kernel (this may take a while)..."

    cd "$BUILD_DIR/linux-${KERNEL_VERSION}"

    make -j$(nproc) >> "$LOG_FILE" 2>&1 || error "Kernel build failed"

    success "Kernel built successfully"
}

# ============================================
# Install Kernel
# ============================================

install_kernel() {
    log "Installing kernel modules..."

    cd "$BUILD_DIR/linux-${KERNEL_VERSION}"

    make modules_install INSTALL_MOD_PATH="$LFS_ROOT" \
        >> "$LOG_FILE" 2>&1 || error "Failed to install modules"

    log "Copying vmlinuz to LFS root..."
    mkdir -p "$LFS_ROOT/boot"

    cp arch/x86/boot/bzImage "$LFS_ROOT/boot/vmlinuz" \
        || error "Failed to copy vmlinuz"

    cp System.map "$LFS_ROOT/boot/System.map-${KERNEL_VERSION}" \
        >> "$LOG_FILE" 2>&1 || true

    cp .config "$LFS_ROOT/boot/config-${KERNEL_VERSION}" \
        >> "$LOG_FILE" 2>&1 || true

    # Generate module dependencies
    if [ -d "$LFS_ROOT/lib/modules/${KERNEL_VERSION}-haramchy" ]; then
        depmod -a "$KERNEL_VERSION-haramchy" 2>/dev/null || true
    fi

    success "Kernel installed to $LFS_ROOT/boot/vmlinuz"
}

# ============================================
# Cleanup
# ============================================

cleanup() {
    log "Cleaning up build directory..."
    rm -rf "$BUILD_DIR/linux-${KERNEL_VERSION}"
    success "Cleanup complete"
}

# ============================================
# Main
# ============================================

main() {
    echo ""
    echo -e "${TEAL}╔═══════════════════════════════════════╗${NC}"
    echo -e "${TEAL}║   HARAMchy Kernel Build System        ║${NC}"
    echo -e "${TEAL}╚═══════════════════════════════════════╝${NC}"
    echo ""

    : > "$LOG_FILE"

    check_prerequisites
    download_kernel
    configure_kernel
    build_kernel
    install_kernel
    cleanup

    echo ""
    success "Kernel build complete!"
    echo ""
}

main "$@"
