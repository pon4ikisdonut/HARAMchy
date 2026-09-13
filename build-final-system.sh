#!/usr/bin/env bash

###############################################################################
# HARAMchy LFS Final System Build
# Chapter 8 - Remaining packages and system configuration
###############################################################################

export LFS=/mnt/lfs
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
export LC_ALL=POSIX

SRC=/sources
BUILD=/tmp/build
MARKERS=/home/lfs/.build-markers/final
LOG_FILE=/var/log/haramchy-final.log

mkdir -p "$BUILD" "$MARKERS" /var/log 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${GREEN}[BUILD]${NC} $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
pkg()   { echo -e "${BOLD}── $* ──${NC}" | tee -a "$LOG_FILE"; }

is_done()   { [[ -f "$MARKERS/$1" ]]; }
mark_done() { date '+%Y-%m-%d %H:%M:%S' > "$MARKERS/$1"; log "  Marked complete: $1"; }

find_tarball() {
    local prefix="$1"
    for ext in tar.xz tar.gz tar.bz2 tar.zst; do
        local match
        match=$(ls "$SRC"/"$prefix"*."$ext" 2>/dev/null | head -n1 || true)
        if [[ -n "$match" ]]; then echo "$match"; return 0; fi
    done
    return 1
}

enter_build() {
    local tarball="$1" explicit_dir="${2:-}" marker="${3:-}"
    if [[ -n "$marker" ]] && is_done "$marker"; then log "  Already built, skipping."; return 2; fi
    local tarball_path; tarball_path=$(find_tarball "$tarball")
    if [[ $? -ne 0 ]] || [[ ! -f "$tarball_path" ]]; then error "  Tarball not found: $tarball"; return 1; fi
    rm -rf "$BUILD"/*
    log "  Extracting $(basename "$tarball_path")..."
    tar -xf "$tarball_path" -C "$BUILD"
    if [[ -n "$explicit_dir" ]]; then
        cd "$BUILD/$explicit_dir"
    else
        local dirs; dirs=($(ls -1d "$BUILD"/*/ 2>/dev/null || true))
        if [[ ${#dirs[@]} -eq 1 ]]; then cd "${dirs[0]}"; else error "  Could not determine dir"; return 1; fi
    fi
}

standard_build() {
    local prefix="${1:-/usr}" sysconfdir="${2:-/etc}" localstatedir="${3:-/var}"
    shift 3 2>/dev/null || true
    log "  Configuring..."
    if ! ./configure --prefix="$prefix" --sysconfdir="$sysconfdir" --localstatedir="$localstatedir" "$@" >> "$LOG_FILE" 2>&1; then
        error "  Configure failed!"; return 1
    fi
    log "  Building..."
    if ! make -j"$(nproc)" >> "$LOG_FILE" 2>&1; then error "  Build failed!"; return 1; fi
    log "  Installing..."
    if ! make install >> "$LOG_FILE" 2>&1; then error "  Install failed!"; return 1; fi
}

cleanup_build() { rm -rf "$BUILD"/*; }
cleanup_build_on_error() { log "  Build dir preserved at $BUILD for debugging"; }

# ── Packages ─────────────────────────────────────────────────────────────────

build_e2fsprogs() {
    pkg "e2fsprogs"; local m="e2fsprogs-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    enter_build "e2fsprogs" "" "$m" || return 0
    mkdir -v build && cd build
    ../configure --prefix=/usr --bindir=/bin --with-root-prefix="" \
        --enable-libblkid --enable-libuuid --enable-libmount --disable-static \
        >> "$LOG_FILE" 2>&1 || { error "  Configure failed!"; return 1; }
    make >> "$LOG_FILE" 2>&1 || { error "  Build failed!"; return 1; }
    make install >> "$LOG_FILE" 2>&1 || { error "  Install failed!"; return 1; }
    rm -fv /etc/{fsck,readtab}.conf
    mark_done "$m"; cleanup_build
}

build_shadow() {
    pkg "shadow"; local m="shadow-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    enter_build "shadow" "" "$m" || return 0

    # Disable features that need external deps
    sed -i 's@#define ENABLE_SUBIDS@/* #define ENABLE_SUBIDS */@' lib/defines.h 2>/dev/null || true

    local libbsd_cflags libbsd_libs
    libbsd_cflags=$(pkg-config --cflags libbsd-overlay 2>/dev/null) || libbsd_cflags=""
    libbsd_libs=$(pkg-config --libs libbsd-overlay 2>/dev/null) || libbsd_libs="-lbsd"

    ./configure --prefix=/usr --bindir=/bin --sbindir=/sbin \
        --sysconfdir=/etc --localstatedir=/var \
        --disable-man --without-libpam --without-selinux --without-acl \
        --without-attr --without-audit --without-nscd \
        CFLAGS="$libbsd_cflags -O2" LDFLAGS="$libbsd_libs" \
        >> "$LOG_FILE" 2>&1 || { error "  Configure failed!"; return 1; }

    make >> "$LOG_FILE" 2>&1 || { error "  Build failed!"; return 1; }
    make install >> "$LOG_FILE" 2>&1 || { error "  Install failed!"; return 1; }
    chmod -v 0600 /etc/shadow 2>/dev/null || true
    mark_done "$m"; cleanup_build
}

build_sysvinit() {
    pkg "sysvinit"; local m="sysvinit-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    enter_build "sysvinit" "" "$m" || return 0

    make >> "$LOG_FILE" 2>&1 || { error "  Build failed!"; return 1; }
    make install >> "$LOG_FILE" 2>&1 || { error "  Install failed!"; return 1; }
    mark_done "$m"; cleanup_build
}

build_procps_ng() {
    pkg "procps-ng"; local m="procps-ng-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    enter_build "procps-ng" "" "$m" || return 0

    standard_build /usr /etc /var --disable-static --without-ncurses || return 1
    mark_done "$m"; cleanup_build
}

# ── System Configuration ─────────────────────────────────────────────────────

setup_essential_symlinks() {
    pkg "Essential symlinks"
    local m="symlinks-done"
    if is_done "$m"; then log "  Already done."; return 0; fi

    # Create essential symlinks (LFS 8.2)
    ln -sfv /usr/bin/{bash,cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin/ 2>/dev/null
    ln -sfv /usr/bin/{dir,ln,ls,mkdir,mknod,mktemp,nohup,rm,rmdir,stty,sync,touch,uname} /bin/ 2>/dev/null
    ln -sfv /usr/bin/{chroot,env,install,link,nice,readlink,test} /usr/sbin/ 2>/dev/null

    # Create /etc/hostname
    mkdir -p /etc/sysconfig
    echo "haramchy" > /etc/hostname

    # Create /etc/hosts
    cat > /etc/hosts << 'HOSTS'
127.0.0.1 localhost
::1 localhost
127.0.1.1 haramchy
HOSTS

    # Create /etc/hosts
    cat > /etc/hosts << 'HOSTS'
127.0.0.1 localhost
::1 localhost
127.0.1.1 haramchy
HOSTS

    # Create /etc/os-release
    cat > /etc/os-release << 'OSRELEASE'
NAME="HARAMchy"
VERSION="1.0"
ID=haramchy
PRETTY_NAME="HARAMchy Linux"
HOME_URL="https://github.com/pon4ikisdonut/HARAMchy"
BUG_REPORT_URL="https://github.com/pon4ikisdonut/HARAMchy/issues"
OSRELEASE

    # Create /etc/passwd
    cat > /etc/passwd << 'PASSWD'
root:x:0:0:root:/root:/bin/bash
lfs:x:1000:1000:lfs:/home/lfs:/bin/bash
PASSWD

    # Create /etc/group
    cat > /etc/group << 'GROUP'
root:x:0:
lfs:x:1000:
GROUP

    # Create /etc/fstab
    cat > /etc/fstab << 'FSTAB'
# <fs>      <mountpoint>  <type>  <opts>         <dump> <pass>
/dev/sda1   /             ext4    defaults        1      1
proc         /proc         proc    nosuid,noexec,nodev 0      0
sysfs        /sys          sysfs   nosuid,noexec,nodev 0      0
devpts       /dev/pts      devpts  gid=5,mode=620      0      0
tmpfs        /run          tmpfs   nosuid,nodev,mode=0755 0    0
devtmpfs     /dev          devtmpfs mode=0755,nosuid    0      0
FSTAB

    # Create /etc/ld.so.conf
    cat > /etc/ld.so.conf << 'LDCONF'
/opt/lib
/lib
/usr/lib
LDCONF

    # Create /etc/inputrc
    cat > /etc/inputrc << 'INPUTRC'
set input-meta on
set output-meta on
set convert-meta off
"\e[A": history-search-backward
"\e[B": history-search-forward
"\e[C": forward-char
"\e[D": backward-char
INPUTRC

    # Create /etc/shells
    cat > /etc/shells << 'SHELLS'
/bin/sh
/bin/bash
SHELLS

    mark_done "$m"
}

setup_clock() {
    pkg "Clock setup"
    local m="clock-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    ln -sfv /usr/share/zoneinfo/UTC /etc/localtime
    cat > /etc/sysconfig/clock << 'CLOCK'
TIMEZONE=UTC
CLOCK
    mark_done "$m"
}

setup_console() {
    pkg "Console setup"
    local m="console-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    cat > /etc/sysconfig/console << 'CONSOLE'
KEYMAP="us"
FONT=""
CONSOLE
    mark_done "$m"
}

setup_profile() {
    pkg "Shell profile"
    local m="profile-done"
    if is_done "$m"; then log "  Already done."; return 0; fi

    cat > /etc/profile << 'PROFILE'
export PATH=/usr/bin:/bin
export LANG=en_US.UTF-8
export PS1='[\u@\h \w]\$ '
PROFILE

    cat > /etc/inputrc << 'INPUTRC'
set input-meta on
set output-meta on
set convert-meta off
INPUTRC

    mark_done "$m"
}

setup_locales() {
    pkg "Locale"
    local m="locale-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true
    cat > /etc/profile.d/locale.sh << 'LOCALE'
export LANG=en_US.UTF-8
LOCALE
    chmod +x /etc/profile.d/locale.sh 2>/dev/null || true
    mark_done "$m"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║   HARAMchy LFS Final System Build               ║"
    log "║   Chapter 8 - System Configuration              ║"
    log "╚══════════════════════════════════════════════════╝"
    log ""

    local start_time; start_time=$(date +%s)
    local failed=()

    run() {
        local name="$1"; shift
        log ""
        if "$@"; then true; else failed+=("$name"); fi
    }

    # System configuration
    run "symlinks"       setup_essential_symlinks
    run "clock"          setup_clock
    run "console"        setup_console
    run "profile"        setup_profile
    run "locale"         setup_locales

    # Remaining packages
    run "shadow"         build_shadow
    run "sysvinit"       build_sysvinit
    run "procps-ng"      build_procps_ng

    local end_time; end_time=$(date +%s)
    local elapsed=$(( end_time - start_time ))
    local minutes=$(( elapsed / 60 ))
    local seconds=$(( elapsed % 60 ))

    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║   Final System Build Complete                   ║"
    log "╚══════════════════════════════════════════════════╝"
    log ""
    if [[ ${#failed[@]} -gt 0 ]]; then
        log "Failed: ${failed[*]}"
    else
        log "All tasks passed!"
    fi
    log "Total time: ${minutes}m ${seconds}s"
}

main "$@"
