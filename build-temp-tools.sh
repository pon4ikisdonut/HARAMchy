#!/usr/bin/env bash

###############################################################################
# HARAMchy LFS Temporary Tools Build Script
# Builds Chapter 6 packages inside chroot (LFS 12.0 methodology)
# Run inside chroot only
###############################################################################

# ── Environment ──────────────────────────────────────────────────────────────

export LFS=/mnt/lfs
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
export LC_ALL=POSIX

SRC=/sources
BUILD=/tmp/build
MARKERS=/home/lfs/.build-markers/tmp-tools
LOG_FILE=/var/log/haramchy-tmp-tools.log

mkdir -p "$BUILD" "$MARKERS" /var/log 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BUILD]${NC} $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
info()  { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
pkg()   { echo -e "${BOLD}── $* ──${NC}" | tee -a "$LOG_FILE"; }

# ── Helpers ──────────────────────────────────────────────────────────────────

is_done() {
    [[ -f "$MARKERS/$1" ]]
}

mark_done() {
    date '+%Y-%m-%d %H:%M:%S' > "$MARKERS/$1"
    log "  Marked complete: $1"
}

find_tarball() {
    local prefix="$1"
    for ext in tar.xz tar.gz tar.bz2 tar.zst tar.lz tar.lzma; do
        local match
        match=$(ls "$SRC"/"$prefix"*."$ext" 2>/dev/null | head -n1 || true)
        if [[ -n "$match" ]]; then
            echo "$match"
            return 0
        fi
    done
    return 1
}

enter_build() {
    local tarball="$1"
    local explicit_dir="${2:-}"
    local marker="${3:-}"

    if [[ -n "$marker" ]] && is_done "$marker"; then
        info "  Already built, skipping."
        return 2
    fi

    local tarball_path
    tarball_path=$(find_tarball "$tarball")
    if [[ $? -ne 0 ]] || [[ ! -f "$tarball_path" ]]; then
        error "  Tarball not found: $tarball"
        return 1
    fi

    rm -rf "$BUILD"/*

    log "  Extracting $(basename "$tarball_path")..."
    case "$tarball_path" in
        *.tar.xz)   tar -xf "$tarball_path" -C "$BUILD" ;;
        *.tar.gz)   tar -xzf "$tarball_path" -C "$BUILD" ;;
        *.tar.bz2)  tar -xjf "$tarball_path" -C "$BUILD" ;;
        *.tar.zst)  tar -I zstd -xf "$tarball_path" -C "$BUILD" ;;
        *)          tar -xf "$tarball_path" -C "$BUILD" ;;
    esac

    if [[ -n "$explicit_dir" ]]; then
        cd "$BUILD/$explicit_dir"
    else
        local dirs
        dirs=($(ls -1d "$BUILD"/*/ 2>/dev/null || true))
        if [[ ${#dirs[@]} -eq 1 ]]; then
            cd "${dirs[0]}"
        else
            error "  Could not determine extracted directory"
            return 1
        fi
    fi
}

standard_build() {
    local prefix="${1:-/usr}"
    local extra_configure="${2:-}"
    local sysconfdir="${3:-/etc}"
    local localstatedir="${4:-/var}"

    log "  Configuring..."
    if [[ -n "$extra_configure" ]]; then
        if ! ./configure --prefix="$prefix" --sysconfdir="$sysconfdir" --localstatedir="$localstatedir" $extra_configure >> "$LOG_FILE" 2>&1; then
            error "  Configure failed!"
            return 1
        fi
    else
        if ! ./configure --prefix="$prefix" --sysconfdir="$sysconfdir" --localstatedir="$localstatedir" >> "$LOG_FILE" 2>&1; then
            error "  Configure failed!"
            return 1
        fi
    fi

    log "  Building ($(nproc) jobs)..."
    if ! make -j"$(nproc)" >> "$LOG_FILE" 2>&1; then
        error "  Build failed!"
        return 1
    fi

    log "  Installing..."
    if ! make install >> "$LOG_FILE" 2>&1; then
        error "  Install failed!"
        return 1
    fi
}

cleanup_build() {
    rm -rf "$BUILD"/*
}

# ── Build functions ──────────────────────────────────────────────────────────

build_tzdata() {
    pkg "tzdata"
    local m="tzdata-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "tzdata" "" "$m" || return 0

    ln -sfv /usr/share/zoneinfo/UTC /etc/localtime

    mark_done "$m"
    cleanup_build
}

build_iana_etc() {
    pkg "iana-etc"
    local m="iana-etc-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "iana-etc" "" "$m" || return 0

    cp -v services protocols /etc

    mark_done "$m"
    cleanup_build
}

build_man_db() {
    pkg "man-db"
    local m="man-db-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "man-db" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_groff() {
    pkg "groff"
    local m="groff-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "groff" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_pkg_config() {
    pkg "pkg-config"
    local m="pkg-config-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    if ! enter_build "pkg-config" "" "$m" 2>/dev/null; then
        warn "  pkg-config tarball not found; using system pkg-config if available."
        mark_done "$m"
        return 0
    fi

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_bzip2() {
    pkg "bzip2"
    local m="bzip2-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "bzip2-1.0.8" "" "$m" || return 0

    make -j"$(nproc)" >> "$LOG_FILE" 2>&1
    make PREFIX=/usr install >> "$LOG_FILE" 2>&1

    mark_done "$m"
    cleanup_build
}

build_xz() {
    pkg "xz"
    local m="xz-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "xz-5.4.5" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_zstd() {
    pkg "zstd"
    local m="zstd-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "zstd-1.5.5" "" "$m" || return 0

    make -j"$(nproc)" PREFIX=/usr >> "$LOG_FILE" 2>&1
    make PREFIX=/usr install >> "$LOG_FILE" 2>&1

    mark_done "$m"
    cleanup_build
}

build_file() {
    pkg "file"
    local m="file-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "file-5.48" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_ncurses() {
    pkg "ncurses"
    local m="ncurses-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "ncurses-6.4" "" "$m" || return 0

    standard_build /usr "" /etc /var \
        --with-shared --without-debug --without-normal \
        --with-pkg-config-libdir=/usr/lib/pkgconfig \
        --enable-pc-files

    mark_done "$m"
    cleanup_build
}

build_sed() {
    pkg "sed"
    local m="sed-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "sed-4.9" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_psmisc() {
    pkg "psmisc"
    local m="psmisc-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "psmisc-23.6" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_gettext() {
    pkg "gettext"
    local m="gettext-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "gettext" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_bison() {
    pkg "bison"
    local m="bison-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "bison-3.8.2" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_perl() {
    pkg "perl"
    local m="perl-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "perl-5.38.0" "" "$m" || return 0

    standard_build /usr "" /etc /var \
        -Dvendorprefix=/usr \
        -Dman1dir=/usr/share/man/man1 \
        -Dpager="/usr/bin/less -isR" \
        -Duseshrplib

    mark_done "$m"
    cleanup_build
}

build_python() {
    pkg "Python"
    local m="python-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "Python-3.11.6" "" "$m" || return 0

    standard_build /usr "" /etc /var \
        --enable-shared \
        --with-system-expat \
        --with-system-ffi

    mark_done "$m"
    cleanup_build
}

build_texinfo() {
    pkg "texinfo"
    local m="texinfo-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "texinfo-7.1" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_util_linux() {
    pkg "util-linux"
    local m="util-linux-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "util-linux-2.39.1" "" "$m" || return 0

    standard_build /usr "" /etc /var \
        --disable-setuid-flags \
        --disable-chfn-chsh \
        --disable-login \
        --disable-nologin \
        --disable-su \
        --disable-setgroups \
        --disable-static \
        --without-python \
        --without-systemd \
        --without-ncurses \
        ADJTIME_PATH=/var/lib/hwclock/adjtime \
        --docdir=/usr/share/doc/util-linux-2.39.1

    mark_done "$m"
    cleanup_build
}

build_kmod() {
    pkg "kmod"
    local m="kmod-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "kmod-31" "" "$m" || return 0

    standard_build /usr "" /etc /var

    for tool in lsmod modinfo modprobe insmod rmmod depmod; do
        ln -sfv /usr/bin/$tool /usr/sbin/$tool 2>/dev/null || true
    done

    mark_done "$m"
    cleanup_build
}

build_libtool() {
    pkg "libtool"
    local m="libtool-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    if ! enter_build "libtool" "" "$m" 2>/dev/null; then
        warn "  libtool tarball not found; skipping."
        mark_done "$m"
        return 0
    fi

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_make() {
    pkg "make"
    local m="make-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "make-4.3" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_coreutils() {
    pkg "coreutils"
    local m="coreutils-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "coreutils-9.4" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_check() {
    pkg "check"
    local m="check-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    if ! enter_build "check" "" "$m" 2>/dev/null; then
        warn "  check tarball not found; skipping."
        mark_done "$m"
        return 0
    fi

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_diffutils() {
    pkg "diffutils"
    local m="diffutils-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "diffutils-3.10" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_findutils() {
    pkg "findutils"
    local m="findutils-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "findutils-4.9.0" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_gawk() {
    pkg "gawk"
    local m="gawk-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "gawk" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_grep() {
    pkg "grep"
    local m="grep-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    if ! enter_build "grep-3.11" "" "$m" 2>/dev/null; then
        warn "  grep tarball not found; using system grep."
        mark_done "$m"
        return 0
    fi

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_gzip() {
    pkg "gzip"
    local m="gzip-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "gzip-1.13" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_tar() {
    pkg "tar"
    local m="tar-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "tar-1.35" "" "$m" || return 0

    standard_build /usr "" /etc /var

    mark_done "$m"
    cleanup_build
}

build_bash() {
    pkg "bash"
    local m="bash-done"
    if is_done "$m"; then info "  Already done."; return 0; fi

    enter_build "bash-5.2.21" "" "$m" || return 0

    standard_build /usr "" /etc /var \
        --without-bash-malloc \
        --with-installed-readline

    ln -sfv /usr/bin/bash /usr/bin/sh

    mark_done "$m"
    cleanup_build
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║   HARAMchy LFS Temporary Tools Build            ║"
    log "║   Chapter 6 - LFS 12.0                          ║"
    log "╚══════════════════════════════════════════════════╝"
    log ""
    log "Environment:"
    log "  LFS=$LFS"
    log "  PATH=$PATH"
    log "  LC_ALL=$LC_ALL"
    log "  SRC=$SRC"
    log "  MARKERS=$MARKERS"
    log ""

    local start_time
    start_time=$(date +%s)

    # Track failures
    local failed=()
    local pass=0
    local skip=0

    run_build() {
        local name="$1"
        shift
        log ""
        if "$@" >> "$LOG_FILE" 2>&1; then
            pass=$((pass + 1))
        else
            local rc=$?
            if [[ $rc -eq 2 ]]; then
                skip=$((skip + 1))
            else
                error "FAILED: $name (exit code $rc)"
                failed+=("$name")
            fi
        fi
    }

    # ── Build order follows LFS 12.0 Chapter 6 ──
    run_build "tzdata"          build_tzdata
    run_build "iana-etc"        build_iana_etc
    run_build "man-db"          build_man_db
    run_build "groff"           build_groff
    run_build "pkg-config"      build_pkg_config
    run_build "bzip2"           build_bzip2
    run_build "xz"              build_xz
    run_build "zstd"            build_zstd
    run_build "file"            build_file
    run_build "ncurses"         build_ncurses
    run_build "sed"             build_sed
    run_build "psmisc"          build_psmisc
    run_build "gettext"         build_gettext
    run_build "bison"           build_bison
    run_build "perl"            build_perl
    run_build "python"          build_python
    run_build "texinfo"         build_texinfo
    run_build "util-linux"      build_util_linux
    run_build "kmod"            build_kmod
    run_build "libtool"         build_libtool
    run_build "make"            build_make
    run_build "coreutils"       build_coreutils
    run_build "check"           build_check
    run_build "diffutils"       build_diffutils
    run_build "findutils"       build_findutils
    run_build "gawk"            build_gawk
    run_build "grep"            build_grep
    run_build "gzip"            build_gzip
    run_build "tar"             build_tar
    run_build "bash"            build_bash

    local end_time
    end_time=$(date +%s)
    local elapsed=$(( end_time - start_time ))
    local minutes=$(( elapsed / 60 ))
    local seconds=$(( elapsed % 60 ))

    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║   Temporary Tools Build Complete                ║"
    log "╚══════════════════════════════════════════════════╝"
    log ""
    log "Results: $pass passed, $skip skipped, ${#failed[@]} failed"
    if [[ ${#failed[@]} -gt 0 ]]; then
        log "Failed packages: ${failed[*]}"
    fi
    log "Total time: ${minutes}m ${seconds}s"
    log "Log file: $LOG_FILE"
    log ""

    log "=== Installed Tools Summary ==="
    for tool in bash sh sed awk grep find tar gzip bzip2 xz zstd \
                make man perl python3 diff pkg-config; do
        local path
        path=$(which "$tool" 2>/dev/null || true)
        if [[ -n "$path" ]]; then
            log "  $tool: $path"
        fi
    done
    log ""

    if [[ -L /usr/bin/sh ]]; then
        log "/usr/bin/sh -> $(readlink /usr/bin/sh)"
    else
        warn "/usr/bin/sh is not a symlink to bash"
    fi
}

main "$@"
