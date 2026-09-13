#!/bin/bash
set -e

LOGFILE="/home/lfs/logs/kernel-build.log"
LINUX_SRC="/home/lfs/src/linux-6.6.tar.xz"
LINUX_BUILD="/home/lfs/build/linux-6.6"
MODULE_SRC="/mnt/e/projects/haramchy/kernel-src"
LFS_ROOT="/home/lfs/lfs-root"

mkdir -p /home/lfs/logs

exec > >(tee -a "$LOGFILE") 2>&1

echo "=========================================="
echo " Kernel Build Script"
echo " Started: $(date)"
echo "=========================================="

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo bash build-kernel.sh)"
    exit 1
fi

cleanup() {
    echo ""
    echo "Cleaning up build directory..."
    rm -rf "$LINUX_BUILD"
    echo "Cleanup complete."
}
trap cleanup EXIT

echo ""
echo "[1/8] Extracting kernel source..."
mkdir -p /home/lfs/build
cd /home/lfs/build
tar -xf "$LINUX_SRC"
if [[ ! -d "$LINUX_BUILD" ]]; then
    echo "ERROR: Failed to extract kernel source to $LINUX_BUILD"
    exit 1
fi

echo ""
echo "[2/8] Copying haram_guard kernel module..."
cd "$LINUX_BUILD"
mkdir -p security/haram_guard
cp "$MODULE_SRC/haram_guard.c" security/haram_guard/haram_guard.c
cp "$MODULE_SRC/haram_guard.h" security/haram_guard/haram_guard.h
cp "$MODULE_SRC/Kconfig"       security/haram_guard/Kconfig
cp "$MODULE_SRC/Makefile"      security/haram_guard/Makefile

echo ""
echo "[3/8] Patching security/Makefile and security/Kconfig..."
if ! grep -q 'haram_guard' security/Makefile; then
    echo 'obj-$(CONFIG_HARAM_GUARD) += haram_guard/' >> security/Makefile
fi

if ! grep -q 'haram_guard' security/Kconfig; then
    echo 'source "security/haram_guard/Kconfig"' >> security/Kconfig
fi

echo ""
echo "[4/8] Configuring kernel..."
make defconfig
make olddefconfig

echo ""
echo "[5/8] Enabling kernel options..."
scripts/config --enable  CONFIG_HARAM_GUARD
scripts/config --enable  CONFIG_HARAM_GUARD_DEFAULT_ENABLE
scripts/config --set-val CONFIG_HARAM_GUARD_PANIC_TIMEOUT 10

scripts/config --enable  CONFIG_VIRTIO
scripts/config --enable  CONFIG_VIRTIO_PCI
scripts/config --enable  CONFIG_VIRTIO_BLK
scripts/config --enable  CONFIG_VIRTIO_NET

scripts/config --enable  CONFIG_EXT4_FS
scripts/config --enable  CONFIG_TMPFS
scripts/config --enable  CONFIG_DEVTMPFS
scripts/config --enable  CONFIG_BLK_DEV_LOOP

echo ""
echo "[6/8] Building kernel..."
JOBS=$(nproc)
echo "Using $JOBS parallel jobs"
make -j"$JOBS"

echo ""
echo "[7/8] Installing modules and copying boot files..."
mkdir -p "$LFS_ROOT/lib/modules"
mkdir -p "$LFS_ROOT/boot"
make INSTALL_MOD_PATH="$LFS_ROOT" modules_install

cp arch/x86/boot/bzImage "$LFS_ROOT/boot/vmlinuz-6.6"
cp System.map           "$LFS_ROOT/boot/System.map-6.6"
cp .config              "$LFS_ROOT/boot/config-6.6"

echo "=== Verifying kernel artifacts ==="
ls -lh "$LFS_ROOT/boot/"
grep CONFIG_HARAM_GUARD "$LFS_ROOT/boot/config-6.6"

echo ""
echo "[8/8] Building haram-siren..."
mkdir -p "$LFS_ROOT/usr/bin"
if gcc -o "$LFS_ROOT/usr/bin/haram-siren" "$MODULE_SRC/haram-siren.c" -lasound 2>/dev/null; then
    echo "haram-siren built with -lasound"
else
    echo "haram-siren built without -lasound"
    gcc -o "$LFS_ROOT/usr/bin/haram-siren" "$MODULE_SRC/haram-siren.c"
fi

echo ""
echo "=========================================="
echo " Kernel build complete!"
echo " Finished: $(date)"
echo "=========================================="
echo ""
echo "Artifacts:"
echo "  vmlinuz:     $LFS_ROOT/boot/vmlinuz-6.6"
echo "  System.map:  $LFS_ROOT/boot/System.map-6.6"
echo "  config:      $LFS_ROOT/boot/config-6.6"
echo "  modules:     $LFS_ROOT/lib/modules/6.6/"
echo "  haram-siren: $LFS_ROOT/usr/bin/haram-siren"
echo "  haram_guard: built-in (y)"
