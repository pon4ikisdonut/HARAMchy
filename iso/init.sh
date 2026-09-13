#!/bin/bash
# ============================================
# HARAMchy Linux - Minimal Init Script
# ============================================
# This init script is used inside the initramfs
# to mount root and switch to the real init.
# ============================================

set -euo pipefail

export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

log() {
    echo "[init] $1"
}

panic() {
    echo "[init] PANIC: $1" >&2
    exec /bin/sh
}

# Mount essential filesystems
mount_virtual() {
    log "Mounting virtual filesystems..."

    mount -t proc     proc     /proc  2>/dev/null || true
    mount -t sysfs    sysfs    /sys   2>/dev/null || true
    mount -t devtmpfs devtmpfs /dev   2>/dev/null || true
    mount -t tmpfs    tmpfs    /tmp   2>/dev/null || true
    mount -t tmpfs    tmpfs    /run   2>/dev/null || true

    mkdir -p /dev/pts
    mount -t devpts devpts /dev/pts 2>/dev/null || true
}

# Load necessary kernel modules
load_modules() {
    log "Loading kernel modules..."

    for mod in virtio virtio_blk virtio_pci sd_mod sr_mod \
               ahci nvme usb_storage xhci_hcd ext4 vfat \
               loop squashfs; do
        modprobe "$mod" 2>/dev/null || true
    done
}

# Detect root device
detect_root() {
    log "Detecting root device..."

    # Try by-label
    for dev in /dev/disk/by-label/*; do
        if [ -b "$dev" ]; then
            local label
            label="$(blkid -s LABEL -o value "$dev" 2>/dev/null || true)"
            if [ "$label" = "HARAMCHY" ] || [ "$label" = "haramchy" ]; then
                echo "$dev"
                return 0
            fi
        fi
    done

    # Try by-uuid
    for dev in /dev/disk/by-uuid/*; do
        if [ -b "$dev" ]; then
            echo "$dev"
            return 0
        fi
    done

    # Fallback to sda1
    if [ -b /dev/sda1 ]; then
        echo "/dev/sda1"
        return 0
    fi

    # Try nvme
    if [ -b /dev/nvme0n1p1 ]; then
        echo "/dev/nvme0n1p1"
        return 0
    fi

    return 1
}

# Mount root filesystem
mount_root() {
    log "Mounting root filesystem..."

    local root_dev
    root_dev="$(detect_root)" || panic "Cannot find root device"

    log "Using root device: $root_dev"

    mkdir -p /mnt/root

    # Try ext4 first
    if mount -t ext4 "$root_dev" /mnt/root 2>/dev/null; then
        log "Mounted root as ext4"
        return 0
    fi

    # Try squashfs (live mode)
    if mount -t squashfs "$root_dev" /mnt/root 2>/dev/null; then
        log "Mounted root as squashfs (live mode)"
        return 0
    fi

    # Try vfat
    if mount -t vfat "$root_dev" /mnt/root 2>/dev/null; then
        log "Mounted root as vfat"
        return 0
    fi

    panic "Failed to mount root filesystem"
}

# Switch to real init
switch_root() {
    log "Switching to real init..."

    if [ -x /mnt/root/sbin/init ]; then
        umount /proc 2>/dev/null || true
        umount /sys  2>/dev/null || true
        umount /dev 2>/dev/null || true
        umount /tmp 2>/dev/null || true
        umount /run 2>/dev/null || true

        exec switch_root /mnt/root /sbin/init
    fi

    if [ -x /mnt/root/usr/sbin/init ]; then
        umount /proc 2>/dev/null || true
        umount /sys  2>/dev/null || true
        umount /dev 2>/dev/null || true
        umount /tmp 2>/dev/null || true
        umount /run 2>/dev/null || true

        exec switch_root /mnt/root /usr/sbin/init
    fi

    panic "No init found in /mnt/root"
}

# Emergency shell
emergency_shell() {
    echo ""
    echo "============================================"
    echo "  HARAMchy Emergency Shell"
    echo "============================================"
    echo ""
    echo "Root device could not be mounted."
    echo "Dropping to emergency shell."
    echo ""
    exec /bin/sh
}

# ============================================
# Main
# ============================================

main() {
    log "HARAMchy init starting..."

    mount_virtual
    load_modules

    if mount_root; then
        switch_root
    else
        emergency_shell
    fi
}

main "$@"
