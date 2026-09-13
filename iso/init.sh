#!/bin/sh
# ============================================
# HARAMchy Linux - Live Boot Init
# ============================================
# This script boots from ISO:
# 1. Finds the ISO media (CD/USB)
# 2. Mounts squashfs root from it
# 3. Creates overlay with tmpfs
# 4. switch_root into the live system
# ============================================

export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

log() {
    echo "[haramchy] $1"
}

panic() {
    echo ""
    echo "============================================"
    echo "  HARAMchy Init Failed"
    echo "  $1"
    echo "============================================"
    echo ""
    exec /bin/sh
}

# Mount virtual filesystems
mount_proc_sys_dev() {
    mount -t proc     proc     /proc  2>/dev/null
    mount -t sysfs    sysfs    /sys   2>/dev/null
    mount -t devtmpfs devtmpfs /dev   2>/dev/null
    mount -t tmpfs    tmpfs    /tmp   2>/dev/null
    mkdir -p /dev/pts
    mount -t devpts devpts /dev/pts 2>/dev/null
}

# Load essential modules
load_modules() {
    for mod in ext4 vfat fat loop squashfs sr_mod sd_mod \
               ahci libahci nvme usb-storage xhci-hcd \
               virtio_blk virtio_pci virtio virtio_ring \
               isofs; do
        modprobe "$mod" 2>/dev/null || true
    done
}

# Find the ISO media
find_iso_media() {
    log "Searching for HARAMchy ISO media..."

    # Search all block devices for an ISO filesystem
    for dev in /dev/sr0 /dev/sr1 /dev/cdrom \
               /dev/sda /dev/sdb /dev/sdc /dev/sdd \
               /dev/vda /dev/vdb /dev/nvme0n1; do
        if [ -b "$dev" ]; then
            # Check if it's an ISO9660 filesystem
            if blkid -s TYPE -o value "$dev" 2>/dev/null | grep -q "iso9660"; then
                log "Found ISO on $dev"
                echo "$dev"
                return 0
            fi
        fi
    done

    # Try by-label
    for dev in /dev/disk/by-label/*; do
        if [ -b "$dev" ]; then
            local label
            label="$(blkid -s LABEL -o value "$dev" 2>/dev/null)"
            if [ "$label" = "HARAMCHY" ]; then
                log "Found HARAMchy media: $dev"
                echo "$dev"
                return 0
            fi
        fi
    done 2>/dev/null

    return 1
}

# Mount the live system
mount_live_root() {
    local iso_dev
    iso_dev="$(find_iso_media)" || {
        log "No ISO media found, trying direct root mount..."
        return 1
    }

    log "Mounting ISO media: $iso_dev"
    mkdir -p /run/media
    mount -t iso9660 "$iso_dev" /run/media 2>/dev/null || {
        mount -o ro "$iso_dev" /run/media 2>/dev/null || {
            log "Failed to mount ISO media"
            return 1
        }
    }

    # Check for squashfs
    if [ ! -f /run/media/live/rootfs.squashfs ]; then
        log "rootfs.squashfs not found on media"
        return 1
    fi

    log "Mounting squashfs..."
    mkdir -p /run/squashfs
    mount -t squashfs -o ro /run/media/live/rootfs.squashfs /run/squashfs || {
        log "Failed to mount squashfs"
        return 1
    }

    log "Setting up overlay..."
    mkdir -p /run/overlay/upper /run/overlay/work
    mount -t tmpfs tmpfs /run/overlay 2>/dev/null || {
        log "Failed to create overlay tmpfs"
        return 1
    }
    mkdir -p /run/overlay/upper /run/overlay/work

    mount -t overlay overlay \
        -o lowerdir=/run/squashfs,upperdir=/run/overlay/upper,workdir=/run/overlay/work \
        /mnt/root 2>/dev/null || {
        log "Overlay mount failed, using squashfs directly..."
        mkdir -p /mnt/root
        mount --bind /run/squashfs /mnt/root
    }

    log "Live root mounted successfully"
    return 0
}

# Mount a physical root (non-live)
mount_physical_root() {
    log "Trying physical root..."

    for dev in /dev/sda1 /dev/sdb1 /dev/vda1 /dev/nvme0n1p1; do
        if [ -b "$dev" ]; then
            mkdir -p /mnt/root
            if mount -t ext4 "$dev" /mnt/root 2>/dev/null; then
                log "Physical root mounted on $dev"
                return 0
            fi
        fi
    done

    return 1
}

# Prepare the root for switch_root
prepare_root() {
    # Create essential directories in the new root
    mkdir -p /mnt/root/{proc,sys,dev,tmp,run,etc}

    # Mount essential filesystems in new root
    mount -t proc  proc  /mnt/root/proc  2>/dev/null
    mount -t sysfs sysfs /mnt/root/sys   2>/dev/null
    mount -t devtmpfs devtmpfs /mnt/root/dev 2>/dev/null
    mount -t tmpfs  tmpfs /mnt/root/tmp  2>/dev/null
    mount -t tmpfs  tmpfs /mnt/root/run  2>/dev/null

    # Copy /dev into the new root (for device nodes)
    cp -a /dev/* /mnt/root/dev/ 2>/dev/null || true
}

# Switch to the real root
do_switch_root() {
    log "Switching to real root..."

    # Unmount old filesystems
    umount /proc 2>/dev/null || true
    umount /sys  2>/dev/null || true
    umount /dev/pts 2>/dev/null || true
    umount /tmp  2>/dev/null || true

    if [ -x /mnt/root/sbin/init ]; then
        log "Executing /sbin/init..."
        exec switch_root /mnt/root /sbin/init
    fi
    if [ -x /mnt/root/usr/sbin/init ]; then
        log "Executing /usr/sbin/init..."
        exec switch_root /mnt/root /usr/sbin/init
    fi
    if [ -x /mnt/root/lib/systemd/systemd ]; then
        log "Executing systemd..."
        exec switch_root /mnt/root /lib/systemd/systemd
    fi

    panic "No init found in /mnt/root"
}

# ============================================
# Main
# ============================================

log "============================================"
log "  HARAMchy Linux - Starting Live Boot"
log "  Kernel: $(uname -r)"
log "============================================"

mount_proc_sys_dev
load_modules

# Show available block devices
log "Block devices:"
ls /dev/sd* /dev/vd* /dev/sr* /dev/nvme* 2>/dev/null || true

# Try live boot first, then physical root
if mount_live_root; then
    prepare_root
    do_switch_root
fi

if mount_physical_root; then
    prepare_root
    do_switch_root
fi

# If nothing worked, try to find any bootable partition
log "Trying any available partition..."
for dev in /dev/sd?1 /dev/vd?1 /dev/nvme?n?p1; do
    for fs in ext4 btrfs xfs; do
        mkdir -p /mnt/root
        if mount -t "$fs" "$dev" /mnt/root 2>/dev/null; then
            log "Mounted $dev as $fs"
            prepare_root
            do_switch_root
        fi
    done
done

panic "Could not find or mount any root filesystem"
