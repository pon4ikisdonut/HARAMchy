#!/bin/bash
set -e

###############################################################################
# HARAMchy LFS Chroot Setup Script
# Creates basic chroot environment and enters to build temp tools
# Run as root: sudo bash chroot-setup.sh
###############################################################################

LFS=/home/lfs/lfs-root
SOURCES_HOST=/home/lfs/src

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HARAMchy]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [[ $EUID -ne 0 ]]; then
    err "Must be run as root (sudo bash chroot-setup.sh)"
    exit 1
fi

if [[ ! -d "$LFS" ]]; then
    err "LFS root not found at $LFS"
    exit 1
fi

# ── Cleanup function ─────────────────────────────────────────────────────────

cleanup() {
    log "Unmounting virtual filesystems..."
    for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
        if mountpoint -q "$mp" 2>/dev/null; then
            umount "$mp" 2>/dev/null || true
        fi
    done
    log "Cleanup complete."
}
trap cleanup EXIT

# ── Chapter 7.2: Preparing Virtual Kernel File Systems ──────────────────────

log "=== Mounting virtual filesystems ==="

mkdir -p "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run" 2>/dev/null || true

mountpoint -q "$LFS/dev"     || { mount --bind /dev "$LFS/dev"; log "  /dev bound"; }
mountpoint -q "$LFS/dev/pts" || { mount --bind /dev/pts "$LFS/dev/pts"; log "  /dev/pts bound"; }
mountpoint -q "$LFS/proc"    || { mount -vt proc proc "$LFS/proc"; log "  /proc mounted"; }
mountpoint -q "$LFS/sys"     || { mount -vt sysfs sysfs "$LFS/sys"; log "  /sys mounted"; }
mountpoint -q "$LFS/run"     || { mount -t tmpfs tmpfs "$LFS/run"; log "  /run mounted"; }

# ── Copy resolv.conf ─────────────────────────────────────────────────────────

if [[ -f /etc/resolv.conf ]]; then
    cp /etc/resolv.conf "$LFS/etc/resolv.conf"
    log "Copied /etc/resolv.conf"
fi

# ── Create /dev/null and /dev/zero if missing ────────────────────────────────

if [[ ! -e "$LFS/dev/null" ]]; then
    mknod -m 666 "$LFS/dev/null" c 1 3
fi
if [[ ! -e "$LFS/dev/zero" ]]; then
    mknod -m 666 "$LFS/dev/zero" c 1 5
fi
if [[ ! -e "$LFS/dev/tty" ]]; then
    mknod -m 666 "$LFS/dev/tty" c 5 0
fi
if [[ ! -e "$LFS/dev/random" ]]; then
    mknod -m 666 "$LFS/dev/random" c 1 8
fi
if [[ ! -e "$LFS/dev/urandom" ]]; then
    mknod -m 666 "$LFS/dev/urandom" c 1 9
fi
log "Ensured essential /dev nodes exist"

# ── Create bootstrap directory (host libs for initial chroot entry) ───────────

log "Setting up bootstrap environment..."
mkdir -p "$LFS/bootstrap"
for lib in ld-linux-x86-64.so.2; do
    if [[ -f "/lib64/$lib" ]]; then
        cp -f "/lib64/$lib" "$LFS/bootstrap/"
    fi
done
for lib in libc.so.6 libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libnss_dns.so.2 libnss_files.so.2 libgmp.so.10; do
    src=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$lib" 2>/dev/null | head -1)
    if [[ -n "$src" ]]; then
        cp -f "$src" "$LFS/bootstrap/"
    fi
done

# Copy host bash as bootstrap shell
cp -f /bin/bash "$LFS/bin/bash"
ln -sf bash "$LFS/bin/sh"
mkdir -p "$LFS/usr/bin"
cp -f /usr/bin/env "$LFS/usr/bin/env" 2>/dev/null || true

# Copy host GCC and binutils for building packages in chroot (Chapter 8)
log "Copying host GCC and binutils for package compilation..."
for bin in gcc gcc-11 cc cpp as ld objcopy objdump strip nm ar ranlib readelf; do
    if [[ -f "/usr/bin/$bin" ]]; then
        cp -f "/usr/bin/$bin" "$LFS/usr/bin/$bin" 2>/dev/null || true
    fi
done
# GCC support files
mkdir -p "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/include"
for f in cc1 collect2 lto1 lto-wrapper libgcc_s.so libgcc_s.so.1 libstdc++.so libstdc++.so.6 libgomp.so* liblto_plugin.so*; do
    cp -f /usr/lib/gcc/x86_64-linux-gnu/11/$f "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null || true
done
cp -rf /usr/lib/gcc/x86_64-linux-gnu/11/include/* "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/include/" 2>/dev/null || true
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/specs "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null || true
# Runtime libs
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so.1 "$LFS/lib64/" 2>/dev/null || true
cp -f /usr/lib/x86_64-linux-gnu/libstdc++.so.6 "$LFS/lib64/" 2>/dev/null || true
# Additional runtime libs
for lib in libgmp.so.10 libgomp.so.1 libmpfr.so.6 libmpc.so.3 libz.so.1; do
    src=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$lib" 2>/dev/null | head -1)
    if [[ -n "$src" ]]; then
        cp -f "$src" "$LFS/lib64/" 2>/dev/null || true
        cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null || true
    fi
done
log "GCC and binutils copied"

log "Bootstrap environment ready"

# ── Symlink /mnt/lfs -> / ───────────────────────────────────────────────────

mkdir -p "$LFS/mnt" 2>/dev/null || true
if [[ ! -L "$LFS/mnt/lfs" ]]; then
    ln -sf / "$LFS/mnt/lfs"
    log "Created symlink /mnt/lfs -> /"
fi

# ── Symlink sources ──────────────────────────────────────────────────────────

# Remove old symlink if it points to a host path
if [[ -L "$LFS/sources" ]]; then
    rm -f "$LFS/sources"
fi
# Bind-mount host sources directly into chroot
mkdir -p "$LFS/sources"
if ! mountpoint -q "$LFS/sources" 2>/dev/null; then
    mount --bind "$SOURCES_HOST" "$LFS/sources"
    log "Bound $SOURCES_HOST -> $LFS/sources"
fi

# ── Create /etc/passwd and /etc/group (LFS 7.2) ─────────────────────────────

if [[ ! -f "$LFS/etc/passwd" ]]; then
    cat > "$LFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
lfs:x:1000:1000:lfs:/home/lfs:/bin/bash
EOF
    log "Created /etc/passwd"
fi

if [[ ! -f "$LFS/etc/group" ]]; then
    cat > "$LFS/etc/group" << 'EOF'
root:x:0:
lfs:x:1000:
EOF
    log "Created /etc/group"
fi

# ── Create required directories ──────────────────────────────────────────────

mkdir -p "$LFS/root" "$LFS/home/lfs" "$LFS/tmp" "$LFS/var/log" "$LFS/etc" 2>/dev/null || true
chmod 1777 "$LFS/tmp"
log "Created required directories"

# ── Copy build scripts into chroot ───────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/build-temp-tools.sh" "$LFS/home/lfs/build-temp-tools.sh"
chmod +x "$LFS/home/lfs/build-temp-tools.sh"
cp "$SCRIPT_DIR/build-final-system.sh" "$LFS/home/lfs/build-final-system.sh"
chmod +x "$LFS/home/lfs/build-final-system.sh"
log "Copied build scripts into chroot"

# ── Create bootstrap entry script ─────────────────────────────────────────────

cat > "$LFS/tmp/bootstrap.sh" << 'BOOTSTRAP'
#!/bin/bash
export HOME=/root
export TERM="${TERM:-linux}"
export PATH=/usr/bin:/bin:/sbin:/usr/sbin:/tools/bin
export LFS=/mnt/lfs
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
cd /home/lfs

echo "=== Phase 1: Temp Tools (Chapter 6) ==="
/bin/bash /home/lfs/build-temp-tools.sh

echo ""
echo "=== Phase 2: Final System (Chapter 8) ==="
/bin/bash /home/lfs/build-final-system.sh
BOOTSTRAP
chmod +x "$LFS/tmp/bootstrap.sh"

# ── Enter chroot ─────────────────────────────────────────────────────────────

log ""
log "=== Entering chroot ==="
log "LFS root: $LFS"
log ""

# Swap cross-compiled ld-linux and libc with host versions for bootstrap
# The host bash + tools need host's dynamic linker and libc
mv "$LFS/lib64/ld-linux-x86-64.so.2" "$LFS/lib64/ld-linux-x86-64.so.2.cross" 2>/dev/null || true
cp -f "$LFS/bootstrap/ld-linux-x86-64.so.2" "$LFS/lib64/ld-linux-x86-64.so.2"
mv "$LFS/lib64/libc.so.6" "$LFS/lib64/libc.so.6.cross" 2>/dev/null || true
cp -f "$LFS/bootstrap/libc.so.6" "$LFS/lib64/libc.so.6"

# Also copy other host libs the host binaries need
for lib in libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libselinux.so.1 libpcre2-8.so.0 libnss_dns.so.2 libnss_files.so.2 libgmp.so.10; do
    if [[ -f "$LFS/bootstrap/$lib" ]]; then
        mv "$LFS/lib/$lib" "$LFS/lib/${lib}.cross" 2>/dev/null || true
        cp -f "$LFS/bootstrap/$lib" "$LFS/lib/$lib"
    fi
done
# Also put in the multiarch path for good measure
mkdir -p "$LFS/lib/x86_64-linux-gnu"
for lib in libc.so.6 libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libselinux.so.1 libpcre2-8.so.0 libgmp.so.10; do
    if [[ -f "$LFS/bootstrap/$lib" ]]; then
        cp -f "$LFS/bootstrap/$lib" "$LFS/lib/x86_64-linux-gnu/$lib" 2>/dev/null || true
    fi
done

chroot "$LFS" /usr/bin/env -i \
    HOME=/root \
    TERM="${TERM:-linux}" \
    PATH=/usr/bin:/bin:/sbin:/usr/sbin:/tools/bin \
    LFS=/mnt/lfs \
    MAKEFLAGS="-j$(nproc)" \
    /bin/bash /home/lfs/build-temp-tools.sh
CHROOT_EXIT=$?

# Restore cross-compiled libs
mv "$LFS/lib64/ld-linux-x86-64.so.2.cross" "$LFS/lib64/ld-linux-x86-64.so.2" 2>/dev/null || true
mv "$LFS/lib64/libc.so.6.cross" "$LFS/lib64/libc.so.6" 2>/dev/null || true
for lib in libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libselinux.so.1 libpcre2-8.so.0 libnss_dns.so.2 libnss_files.so.2; do
    mv "$LFS/lib/${lib}.cross" "$LFS/lib/$lib" 2>/dev/null || true
done
rm -rf "$LFS/lib/x86_64-linux-gnu"

exit $CHROOT_EXIT

log ""
log "=== Chroot build completed ==="
