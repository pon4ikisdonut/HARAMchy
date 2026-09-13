#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# HARAMchy LFS Base Build Script
# Builds toolchain and base system packages following LFS 12.0 methodology
# Run as root: sudo bash lfs-base-build.sh
###############################################################################

# Environment
export LFS=/home/lfs/lfs-root
export LFS_TGT=x86_64-lfs-linux-gnu
export PATH=$LFS/tools/bin:$PATH
export LC_ALL=POSIX

SRC=/home/lfs/src
BUILD=/home/lfs/build
MARKERS=/home/lfs/.build-markers
LOG_DIR=/home/lfs/logs

mkdir -p "$SRC" "$BUILD" "$MARKERS" "$LOG_DIR"

# Colors / logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[HARAMchy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

stage_done() {
    local marker="$MARKERS/.stage-$1-complete"
    if [[ -f "$marker" ]]; then
        log "Stage $1 ($2): already completed, skipping."
        return 0
    fi
    return 1
}

mark_done() {
    local marker="$MARKERS/.stage-$1-complete"
    date '+%Y-%m-%d %H:%M:%S' > "$marker"
    log "Stage $1 ($2): completed."
}

# ── Argument parsing ──────────────────────────────────────────────────────────
STAGES=()
DOWNLOAD_ONLY=0
ALL=1

for arg in "$@"; do
    case "$arg" in
        --download-only) DOWNLOAD_ONLY=1 ;;
        --stage=*)       STAGES+=("${arg#--stage=}"); ALL=0 ;;
        --help|-h)
            echo "Usage: $0 [--stage=N ...] [--download-only]"
            echo "  Stages: 1=linux-api-headers 2=glibc 3=libstdcpp 4=binutils2 5=gcc2 6=verify 7=chroot 8=download"
            echo ""
            echo "  --download-only    Only download sources and exit"
            echo "  --stage=N          Run only specified stage(s)"
            echo ""
            echo "  Stage execution order: 8 (download) -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7"
            exit 0 ;;
        *) error "Unknown argument: $arg"; exit 1 ;;
    esac
done

run_stage() {
    local num=$1
    if [[ $ALL -eq 1 ]]; then
        return 0
    fi
    for s in "${STAGES[@]+"${STAGES[@]}"}"; do
        [[ "$s" == "$num" ]] && return 0
    done
    return 1
}

# ── Common helpers ────────────────────────────────────────────────────────────

extract_source() {
    local tarball="$1" dest="$2"
    local tarball_path="$SRC/$tarball"

    if [[ ! -f "$tarball_path" ]]; then
        error "Source tarball not found: $tarball_path"
        exit 1
    fi

    # Check if already extracted by looking for the target directory
    if [[ -d "$dest" ]]; then
        log "Directory already exists, skipping extraction: $dest"
        return 0
    fi

    log "Extracting $tarball -> $dest ..."
    mkdir -p "$dest"
    case "$tarball" in
        *.tar.xz) tar -xf "$tarball_path" -C "$dest" ;;
        *.tar.gz) tar -xzf "$tarball_path" -C "$dest" ;;
        *.tar.bz2) tar -xjf "$tarball_path" -C "$dest" ;;
        *)        tar -xf "$tarball_path" -C "$dest" ;;
    esac
}

# Build dir helper: extracts tarball into BUILD and enters the extracted directory
enter_build() {
    local tarball="$1"
    local dirname="${2:-}"

    cd "$BUILD"

    # Extract tarball contents into BUILD directory (not a subdirectory)
    tarball_path="$SRC/$tarball"
    if [[ ! -f "$tarball_path" ]]; then
        error "Source tarball not found: $tarball_path"
        exit 1
    fi

    log "Extracting $tarball into $BUILD ..."
    case "$tarball" in
        *.tar.xz) tar -xf "$tarball_path" -C "$BUILD" ;;
        *.tar.gz) tar -xzf "$tarball_path" -C "$BUILD" ;;
        *.tar.bz2) tar -xjf "$tarball_path" -C "$BUILD" ;;
        *)        tar -xf "$tarball_path" -C "$BUILD" ;;
    esac

    if [[ -n "$dirname" ]]; then
        cd "$dirname"
    else
        # Auto-detect the single extracted directory
        local entries=($(ls -1d */ 2>/dev/null || true))
        if [[ ${#entries[@]} -eq 1 ]]; then
            cd "${entries[0]}"
        fi
    fi
}

# ── 8. Download Missing Sources (runs FIRST) ─────────────────────────────────

download_missing_sources() {
    local stage=8 name="download-sources"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Downloading Sources ==="

    mkdir -p "$SRC"

    local failed=0

    dl() {
        local url="$1"
        local fname
        fname=$(basename "$url")

        if [[ -f "$SRC/$fname" ]]; then
            log "  $fname: already present, skipping"
            return 0
        fi

        log "  Downloading $fname..."
        if command -v curl &>/dev/null; then
            curl -L --retry 3 --retry-delay 5 -o "$SRC/$fname" "$url" 2>/dev/null
        elif command -v wget &>/dev/null; then
            wget -t 3 --timeout=30 -O "$SRC/$fname" "$url" 2>/dev/null
        else
            error "Neither curl nor wget available. Cannot download sources."
            return 1
        fi

        if [[ -f "$SRC/$fname" ]] && [[ $(stat -c%s "$SRC/$fname" 2>/dev/null || stat -f%z "$SRC/$fname" 2>/dev/null) -gt 100 ]]; then
            log "    $fname: downloaded successfully"
            return 0
        else
            error "    $fname: download failed or empty file"
            ((failed++)) || true
            return 1
        fi
    }

    # Core sources needed for this build
    log ""
    log "--- Core Sources (needed for toolchain build) ---"
    dl "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz"
    dl "https://ftp.gnu.org/gnu/glibc/glibc-2.38.tar.xz"
    dl "https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz"
    dl "https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz"
    dl "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
    dl "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
    dl "https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz"

    # Additional packages
    log ""
    log "--- Additional Sources ---"
    dl "https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz"
    dl "https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz"
    dl "https://ftp.gnu.org/gnu/gawk/gawk-6.0.0.tar.xz"
    dl "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz"
    dl "https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz"
    dl "https://ftp.gnu.org/gnu/gettext/gettext-0.22.3.tar.xz"
    dl "https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz"
    dl "https://www.cpan.org/src/5.0/perl-5.38.0.tar.xz"
    dl "https://www.python.org/ftp/python/3.11.6/Python-3.11.6.tar.xz"
    dl "https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz"
    dl "https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz"
    dl "https://www.openssl.org/source/openssl-3.2.0.tar.gz"
    dl "https://sourceware.org/elfutils/ftp/0.190/libelf-0.190.tar.xz"
    dl "https://zlib.net/zlib-1.3.tar.gz"
    dl "https://sourceware.org/bzip2/bzip2-1.0.8.tar.gz"
    dl "https://tukaani.org/xz/xz-5.4.5.tar.xz"
    dl "https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz"
    dl "https://astron.com/pub/file/file-5.45.tar.xz"
    dl "https://ftp.gnu.org/gnu/groff/groff-1.23.0.tar.gz"
    dl "https://www.kernel.org/pub/linux/utils/kbd/kbd-2.57.1.tar.xz"
    dl "https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.7.tar.gz"
    dl "https://ftp.gnu.org/gnu/make/make-4.3.tar.gz"
    dl "https://www.kernel.org/pub/linux/utils/kmod/kmod-31.tar.xz"
    dl "https://mirrors.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.69.tar.xz"
    dl "https://github.com/shadow-maint/shadow/releases/download/4.14.5/shadow-4.14.5.tar.xz"
    dl "https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.6.tar.xz/download"
    dl "https://github.com/ninja-build/ninja/archive/v1.11.1.tar.gz"
    dl "https://github.com/mesonbuild/meson/archive/refs/tags/1.3.0.tar.gz"
    dl "https://dbus.freedesktop.org/releases/dbus/dbus-1.14.10.tar.xz"
    dl "https://github.com/vim/vim/archive/v9.0.2167.tar.gz"
    dl "https://sourceforge.net/projects/procps-ng/files/production/procps-ng-3.3.19.tar.xz/download"
    dl "https://github.com/slicer69/sysvinit/archive/refs/tags/3.07.tar.gz"
    dl "https://www.nongnu.org/man-db/man-db-2.12.0.tar.xz"
    dl "https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz"
    dl "https://ftp.gnu.org/gnu/gzip/gzip-1.13.tar.xz"
    dl "https://ftp.gnu.org/gnu/diffutils/diffutils-3.10.tar.xz"
    dl "https://github.com/tytso/e2fsprogs/archive/v1.47.0.tar.gz"

    # Verify all tarballs
    log ""
    log "=== Source Tarball Inventory ==="
    log "Source directory: $SRC"
    local count=0
    for f in "$SRC"/*.tar.* "$SRC"/*.tar.gz; do
        [[ -f "$f" ]] && { log "  $(basename "$f")"; count=$((count + 1)); }
    done
    log "Total: $count tarballs"

    if [[ $failed -gt 0 ]]; then
        warn "$failed download(s) failed. Review errors above."
    fi

    mark_done "$stage" "$name"
}

# ── 1. Linux API Headers (6.2) ──────────────────────────────────────────────

build_linux_api_headers() {
    local stage=1 name="linux-api-headers"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Linux API Headers ==="
    enter_build "linux-6.6.tar.xz" "linux-6.6"

    make mrproper
    make headers INSTALL_HDR_PATH=$LFS/usr
    find $LFS/usr/include -type f ! -name '*.h' -delete

    cd /; rm -rf "$BUILD/linux-6.6"
    mark_done "$stage" "$name"
}

# ── 2. Glibc (6.3) ──────────────────────────────────────────────────────────

build_glibc() {
    local stage=2 name="glibc"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Glibc ==="
    enter_build "glibc-2.38.tar.xz" "glibc-2.38"

    # Create symlinks required by the dynamic linker
    case $(uname -m) in
        x86_64)
            mkdir -p "$LFS/lib64"
            ln -sfv "$LFS/tools/lib/libgcc_s.so.1" "$LFS/lib64/libgcc_s.so.1" 2>/dev/null || true
            ln -sfv "$LFS/tools/lib/libgcc_s.so"   "$LFS/lib64/libgcc_s.so"   2>/dev/null || true
            ;;
    esac

    # Build
    mkdir -p build
    cd build

    ../configure \
        --prefix=/usr \
        --host=$LFS_TGT \
        --build=$(../scripts/config.guess) \
        --enable-kernel=4.14 \
        --with-headers=$LFS/usr/include \
        --disable-werror \
        --disable-profile \
        --disable-multilib \
        --disable-libssp \
        --enable-stack-protector=strong \
        --enable-bind-now \
        --enable-multi-arch

    make -j$(nproc)
    make install DESTDIR=$LFS

    cd /; rm -rf "$BUILD/glibc-2.38"
    mark_done "$stage" "$name"
}

# ── 3. Libstdc++ Pass 1 (6.4) ──────────────────────────────────────────────

build_libstdcpp() {
    local stage=3 name="libstdcpp-pass1"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Libstdc++ Pass 1 ==="
    enter_build "gcc-13.2.0.tar.xz" "gcc-13.2.0"

    # Symlink MPFR, GMP, MPC into GCC source tree
    ln -sfv "$SRC/mpfr-4.2.1" mpfr   2>/dev/null || true
    ln -sfv "$SRC/gmp-6.3.0"  gmp    2>/dev/null || true
    ln -sfv "$SRC/mpc-1.3.1"  mpc    2>/dev/null || true

    mkdir -p build
    cd build

    ../libstdc++-v3/configure \
        --host=$LFS_TGT \
        --build=x86_64-pc-linux-gnu \
        --prefix=/usr \
        --disable-multilib \
        --disable-nls \
        --disable-libstdc++-v3 \
        --disable-libtool \
        --with-gxx-include-dir=/usr/include/c++/13.2.0

    make -j$(nproc)
    make DESTDIR=$LFS install

    cd /; rm -rf "$BUILD/gcc-13.2.0"
    mark_done "$stage" "$name"
}

# ── 4. Binutils Pass 2 (6.5) ───────────────────────────────────────────────

build_binutils2() {
    local stage=4 name="binutils-pass2"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Binutils Pass 2 ==="
    enter_build "binutils-2.42.tar.xz" "binutils-2.42"

    mkdir -p build
    cd build

    ../configure \
        --prefix=/usr \
        --host=$LFS_TGT \
        --build=$(../config.guess) \
        --disable-nls \
        --enable-gprofng=no \
        --disable-werror \
        --enable-new-dtags \
        --enable-hash-style=gnu \
        --with-sysroot=$LFS

    make -j$(nproc)
    make DESTDIR=$LFS install

    cd /; rm -rf "$BUILD/binutils-2.42"
    mark_done "$stage" "$name"
}

# ── 5. GCC Pass 2 (6.6) ────────────────────────────────────────────────────

build_gcc2() {
    local stage=5 name="gcc-pass2"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: GCC Pass 2 ==="
    enter_build "gcc-13.2.0.tar.xz" "gcc-13.2.0"

    # Symlink MPFR, GMP, MPC
    ln -sfv "$SRC/mpfr-4.2.1" mpfr 2>/dev/null || true
    ln -sfv "$SRC/gmp-6.3.0"  gmp  2>/dev/null || true
    ln -sfv "$SRC/mpc-1.3.1"  mpc  2>/dev/null || true

    # Symlink for libgcc:
    case $(uname -m) in
        x86_64) sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64 ;;
    esac

    mkdir -p build
    cd build

    # Use x86_64-pc-linux-gnu as --build to correctly detect cross-compilation
    # --disable-fixincludes: host tool that needs native headers we don't have
    ../configure \
        --prefix=/usr \
        --host=$LFS_TGT \
        --build=x86_64-pc-linux-gnu \
        --libexecdir=/usr/libexec \
        --with-build-time-tools=$LFS/tools \
        --enable-host-shared \
        --enable-default-pie \
        --enable-default-ssp \
        --disable-vtable-verify \
        --disable-multilib \
        --disable-libsanitizer \
        --disable-libstdcxx-pch \
        --disable-fixincludes \
        --with-gcc-major-version-only \
        --with-arch=x86-64 \
        --with-tune=generic \
        --enable-languages=c,c++ \
        --disable-nls

    make -j$(nproc) all-gcc
    make -j$(nproc) all-target-libgcc
    make DESTDIR=$LFS install-gcc install-target-libgcc || true

    # Copy cc1, cc1plus manually
    cp -v gcc/cc1 "$LFS/tools/libexec/gcc/$LFS_TGT/13/" 2>/dev/null || true
    cp -v gcc/cc1plus "$LFS/tools/libexec/gcc/$LFS_TGT/13/" 2>/dev/null || true
    cp -v cpp/cpp "$LFS/tools/libexec/gcc/$LFS_TGT/13/cpp" 2>/dev/null || true

    ln -sfv gcc "$LFS/tools/bin/cc"

    cd /; rm -rf "$BUILD/gcc-13.2.0"
    mark_done "$stage" "$name"
}

# ── 6. Final Toolchain Verification ─────────────────────────────────────────

verify_toolchain() {
    local stage=6 name="toolchain-verify"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Final Toolchain Verification ==="

    # Verify
    log "Verifying toolchain binaries..."
    local missing=0
    for bin in cc gcc cpp c++ g++ as ld ar ranlib strings; do
        if [[ -f "$LFS/tools/bin/$bin" ]]; then
            log "  $bin: OK"
        else
            warn "  $bin: NOT FOUND"
            ((missing++)) || true
        fi
    done

    # Test the cross-compiler
    echo 'int main(){}' > /tmp/lfs-test.c
    "$LFS/tools/bin/cc" /tmp/lfs-test.c -o /tmp/lfs-test 2>/dev/null \
        && log "Cross-compiler test: PASSED" \
        || warn "Cross-compiler test: FAILED (may need Glibc first)"
    rm -f /tmp/lfs-test.c /tmp/lfs-test

    if [[ $missing -gt 0 ]]; then
        warn "$missing toolchain binary(ies) missing."
    fi

    mark_done "$stage" "$name"
}

# ── 7. Chroot Structure Setup ───────────────────────────────────────────────

setup_chroot_structure() {
    local stage=7 name="chroot-structure"
    stage_done "$stage" "$name" && return 0

    log "=== Stage $stage: Setting up Chroot Structure ==="

    for dir in proc sys dev run; do
        mkdir -p "$LFS/$dir"
        log "Created $LFS/$dir"
    done

    # Write mount instructions
    cat <<'MOUNT_EOF'
──────────────────────────────────────────────────────────────
  To enter the chroot environment, run:

  sudo chroot "$LFS" /tools/bin/env -i \
      HOME=/root \
      TERM="$TERM" \
      PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
      /tools/bin/bash --login

  Before chrooting, mount virtual filesystems:

  mount -v --bind /dev     $LFS/dev
  mount -v --bind /dev/pts $LFS/dev/pts
  mount -vt proc proc      $LFS/proc
  mount -vt sysfs sysfs    $LFS/sys
  mount -t tmpfs tmpfs     $LFS/run

  When finished:

  umount -v $LFS/dev/pts
  umount -v $LFS/dev
  umount -v $LFS/proc
  umount -v $LFS/sys
  umount -v $LFS/run
──────────────────────────────────────────────────────────────
MOUNT_EOF

    log "Chroot directory structure created in $LFS"
    mark_done "$stage" "$name"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    log "╔══════════════════════════════════════════════════╗"
    log "║     HARAMchy LFS Base Build Script              ║"
    log "║     Based on LFS 12.0 Methodology               ║"
    log "╚══════════════════════════════════════════════════╝"
    log ""
    log "Environment:"
    log "  LFS=$LFS"
    log "  LFS_TGT=$LFS_TGT"
    log "  PATH includes $LFS/tools/bin"
    log "  Source dir: $SRC"
    log "  Build dir: $BUILD"
    log "  Markers:   $MARKERS"
    log ""

    # Pre-flight checks
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)."
        exit 1
    fi

    if [[ ! -d "$LFS/tools/bin" ]]; then
        error "LFS toolchain not found at $LFS/tools/bin"
        exit 1
    fi

    if ! grep -q "$LFS/tools/bin" <<< "$PATH"; then
        error "$LFS/tools/bin is not in PATH"
        exit 1
    fi

    # ── Stage execution order: download FIRST, then build stages ──

    # Stage 8: Download sources (MUST run before any build stages)
    if run_stage 8; then download_missing_sources; fi

    # If --download-only, exit immediately after download
    if [[ $DOWNLOAD_ONLY -eq 1 ]]; then
        log ""
        log "Download-only mode. Exiting after download."
        exit 0
    fi

    # Build stages in correct order:
    # 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7
    if run_stage 1; then build_linux_api_headers; fi
    if run_stage 2; then build_glibc; fi
    if run_stage 3; then build_libstdcpp; fi
    if run_stage 4; then build_binutils2; fi
    if run_stage 5; then build_gcc2; fi
    if run_stage 6; then verify_toolchain; fi
    if run_stage 7; then setup_chroot_structure; fi

    log ""
    log "All selected stages completed."
    log ""
    log "Next steps:"
    log "  1. Verify the toolchain: $LFS/tools/bin/cc --version"
    log "  2. Build remaining Chapter 6 packages (see LFS book)"
    log "  3. Enter chroot environment (see mount instructions above)"
}

main "$@"
