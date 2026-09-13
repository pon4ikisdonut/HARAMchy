#!/bin/bash
# ============================================
# HARAMchy Linux - ISO Build Script
# Builds a bootable ISO from the LFS root
# ============================================
set -euo pipefail

LFS_ROOT="/home/lfs/lfs-root"
ISO_WORKSPACE="/home/lfs/iso-workspace"
BUILD_DIR="$ISO_WORKSPACE/build"
STAGE_DIR="$ISO_WORKSPACE/stage"
OUTPUT_DIR="/mnt/e/haramchy/iso"
ISO_NAME="haramchy-$(date +%Y%m%d).iso"
LOG_FILE="/home/lfs/iso-build.log"
ARCH="$(uname -m)"

log()      { echo "[ISO] $1" | tee -a "$LOG_FILE"; }
success()  { echo "[OK] $1" | tee -a "$LOG_FILE"; }
error()    { echo "[ERROR] $1" | tee -a "$LOG_FILE"; exit 1; }

# Prerequisites
for cmd in xorriso mksquashfs grub-mkimage mkfs.vfat; do
    command -v "$cmd" &>/dev/null || error "Required: $cmd"
done
[ -f "$LFS_ROOT/boot/vmlinuz-6.6" ] || error "Kernel not found"
[ -f "$LFS_ROOT/boot/initramfs.img" ] || error "Initramfs not found"

# Prepare workspace
rm -rf "$ISO_WORKSPACE"
mkdir -p "$BUILD_DIR" "$STAGE_DIR/boot/grub" "$STAGE_DIR/live" "$OUTPUT_DIR"

# Copy kernel, initramfs, grub.cfg
cp "$LFS_ROOT/boot/vmlinuz-6.6" "$STAGE_DIR/boot/vmlinuz-6.6"
cp "$LFS_ROOT/boot/initramfs.img" "$STAGE_DIR/boot/initramfs.img"
cp "$(dirname "$0")/grub.cfg" "$STAGE_DIR/boot/grub/grub.cfg"
cp "$(dirname "$0")/init.sh" "$STAGE_DIR/boot/init.sh"
chmod +x "$STAGE_DIR/boot/init.sh"

# Create squashfs
log "Creating squashfs (gzip, this takes a while)..."
mksquashfs "$LFS_ROOT" "$STAGE_DIR/live/rootfs.squashfs" \
    -comp gzip -b 1M -no-exports -no-recovery -wildcards \
    -e 'dev/*' 'proc/*' 'sys/*' 'run/*' 'tmp/*' 'mnt/*' 'media/*' 'home/lfs/*' \
    >> "$LOG_FILE" 2>&1
success "Squashfs: $(du -h "$STAGE_DIR/live/rootfs.squashfs" | cut -f1)"

# Create GRUB BIOS image
log "Creating GRUB BIOS image..."
dd if=/dev/zero of="$BUILD_DIR/bios.img" bs=1M count=1 2>/dev/null
mkfs.vfat "$BUILD_DIR/bios.img" 2>/dev/null

grub-mkimage -O i386-pc -o "$BUILD_DIR/core.img" \
    -p "(hd0,msdos1)/boot/grub" -d "$LFS_ROOT/usr/lib/grub/i386-pc" \
    part_gpt part_msdos biosdisk disk fat iso9660 \
    normal boot linux configfile search search_fs_uuid search_label \
    loopback gzio test all_video loadenv

cat "$LFS_ROOT/usr/lib/grub/i386-pc/boot.img" "$BUILD_DIR/core.img" > "$BUILD_DIR/bios-boot.img"
dd if="$BUILD_DIR/bios-boot.img" of="$BUILD_DIR/bios.img" bs=512 count=1 seek=0 conv=notrunc 2>/dev/null
success "BIOS image created"

# Create GRUB EFI image
log "Creating GRUB EFI image..."
mkdir -p "$BUILD_DIR/grub-efi/EFI/BOOT"

grub-mkimage -O x86_64-efi -o "$BUILD_DIR/grub-efi/EFI/BOOT/BOOTX64.EFI" \
    -p "/boot/grub" -d "$LFS_ROOT/usr/lib/grub/x86_64-efi" \
    part_gpt part_msdos disk fat iso9660 normal boot linux \
    configfile search search_fs_uuid search_label loopback \
    gzio test all_video loadenv

dd if=/dev/zero of="$BUILD_DIR/efiboot.img" bs=1M count=10 2>/dev/null
mkfs.vfat "$BUILD_DIR/efiboot.img" 2>/dev/null
mmd -i "$BUILD_DIR/efiboot.img" ::/EFI ::/EFI/BOOT 2>/dev/null
mcopy -i "$BUILD_DIR/efiboot.img" "$BUILD_DIR/grub-efi/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI 2>/dev/null
success "EFI image created"

# Copy boot images into stage for xorriso
cp "$BUILD_DIR/bios.img" "$STAGE_DIR/boot/bios.img"
cp "$BUILD_DIR/efiboot.img" "$STAGE_DIR/boot/efiboot.img"

# Create ISO
log "Creating ISO image..."
cd "$STAGE_DIR"
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "HARAMCHY" \
    -output "$OUTPUT_DIR/$ISO_NAME" \
    -eltorito-boot boot/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
    -eltorito-alt-boot \
        -e boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    .

cd "$OUTPUT_DIR"
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256sum"

rm -rf "$BUILD_DIR"
success "ISO created: $OUTPUT_DIR/$ISO_NAME ($(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1))"
success "SHA256: $OUTPUT_DIR/$ISO_NAME.sha256sum"
