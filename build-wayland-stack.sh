#!/usr/bin/env bash

###############################################################################
# HARAMchy Wayland/Hyprland Stack Build
# Downloads and builds the minimal Wayland stack for Hyprland
###############################################################################

export LFS=/mnt/lfs
export PATH=/usr/bin:/bin:/sbin:/usr/sbin
export LC_ALL=POSIX

SRC=/sources
BUILD=/tmp/build
MARKERS=/home/lfs/.build-markers/wayland
LOG_FILE=/var/log/haramchy-wayland.log

mkdir -p "$BUILD" "$MARKERS" /var/log 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${GREEN}[BUILD]${NC} $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
pkg()   { echo -e "${BOLD}── $* ──${NC}" | tee -a "$LOG_FILE"; }

is_done()   { [[ -f "$MARKERS/$1" ]]; }
mark_done() { date '+%Y-%m-%d %H:%M:%S' > "$MARKERS/$1"; log "  Marked complete: $1"; }

download() {
    local url="$1" dest="$2"
    if [ -f "$SRC/$dest" ] && [ -s "$SRC/$dest" ]; then
        return 0
    fi
    log "  Downloading $dest..."
    curl -L -o "$SRC/$dest" "$url" 2>/dev/null || wget -q -O "$SRC/$dest" "$url" 2>/dev/null
    if [ ! -s "$SRC/$dest" ]; then
        rm -f "$SRC/$dest"
        return 1
    fi
    return 0
}

enter_build() {
    local name="$1" tarball="$2" marker="$3"
    cleanup_build
    local tarball_path
    tarball_path=$(find_tarball "$tarball")
    if [ -z "$tarball_path" ]; then
        error "  Tarball $tarball not found!"; return 1
    fi
    log "  Extracting $(basename "$tarball_path")..."
    tar xf "$tarball_path" -C "$BUILD" 2>/dev/null || { error "  Extract failed!"; return 1; }
    local dir_name
    dir_name=$(tar tf "$tarball_path" 2>/dev/null | head -1 | sed 's@/.*@@')
    cd "$BUILD/$dir_name" || { error "  cd failed!"; return 1; }
    return 0
}

find_tarball() {
    local prefix="$1"
    for ext in tar.xz tar.gz tar.bz2 tar.zst; do
        local found
        found=$(find "$SRC" -maxdepth 1 -name "${prefix}*${ext}" -type f -size +1k 2>/dev/null | head -1)
        if [ -n "$found" ]; then echo "$found"; return 0; fi
    done
    return 1
}

standard_build() {
    local prefix="${1:-/usr}" sysconfdir="${2:-/etc}" localstatedir="${3:-/var}"
    shift 3 2>/dev/null || true
    log "  Configuring..."
    if ! meson setup build --prefix="$prefix" --sysconfdir="$sysconfdir" --localstatedir="$localstatedir" "$@" >> "$LOG_FILE" 2>&1; then
        # Fallback to autotools
        if ! ./configure --prefix="$prefix" --sysconfdir="$sysconfdir" --localstatedir="$localstatedir" "$@" >> "$LOG_FILE" 2>&1; then
            error "  Configure failed!"; return 1
        fi
        log "  Building..."
        if ! make -j"$(nproc)" >> "$LOG_FILE" 2>&1; then error "  Build failed!"; return 1; fi
        log "  Installing..."
        if ! make install >> "$LOG_FILE" 2>&1; then error "  Install failed!"; return 1; fi
    else
        log "  Building..."
        if ! ninja -C build >> "$LOG_FILE" 2>&1; then error "  Build failed!"; return 1; fi
        log "  Installing..."
        if ! ninja -C build install >> "$LOG_FILE" 2>&1; then error "  Install failed!"; return 1; fi
    fi
}

meson_build() {
    local prefix="${1:-/usr}"
    shift 1 2>/dev/null || true
    log "  Configuring (meson)..."
    rm -rf build
    if ! meson setup build --prefix="$prefix" --default-library=shared "$@" >> "$LOG_FILE" 2>&1; then
        error "  Meson configure failed!"; return 1
    fi
    log "  Building (ninja)..."
    if ! ninja -C build >> "$LOG_FILE" 2>&1; then error "  Build failed!"; return 1; fi
    log "  Installing..."
    if ! ninja -C build install >> "$LOG_FILE" 2>&1; then error "  Install failed!"; return 1; fi
}

cmake_build() {
    local prefix="${1:-/usr}"
    shift 1 2>/dev/null || true
    log "  Configuring (cmake)..."
    rm -rf build
    mkdir -p build
    if ! cmake -B build -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE=Release "$@" >> "$LOG_FILE" 2>&1; then
        error "  CMake configure failed!"; return 1
    fi
    log "  Building..."
    if ! cmake --build build -j"$(nproc)" >> "$LOG_FILE" 2>&1; then error "  Build failed!"; return 1; fi
    log "  Installing..."
    if ! cmake --install build >> "$LOG_FILE" 2>&1; then error "  Install failed!"; return 1; fi
}

cleanup_build() { rm -rf "$BUILD"/*; }

# ── Packages ─────────────────────────────────────────────────────────────────

build_wayland_protocols() {
    pkg "wayland-protocols"; local m="wayland-protocols-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/archive/1.32/wayland-protocols-1.32.tar.gz" "wayland-protocols-1.32.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "wayland-protocols" "wayland-protocols-1.32" "$m" || return 0
    meson_build /usr
    mark_done "$m"; cleanup_build
}

build_wayland() {
    pkg "wayland"; local m="wayland-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://gitlab.freedesktop.org/wayland/wayland/-/archive/1.22.0/wayland-1.22.0.tar.gz" "wayland-1.22.0.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "wayland" "wayland-1.22.0" "$m" || return 0
    meson_build /usr -Ddocumentation=false -Dtests=false
    mark_done "$m"; cleanup_build
}

build_libdrm() {
    pkg "libdrm"; local m="libdrm-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" "libdrm-2.4.120.tar.xz" || { error "  Download failed!"; return 1; }
    enter_build "libdrm" "libdrm-2.4.120" "$m" || return 0
    meson_build /usr
    mark_done "$m"; cleanup_build
}

build_pixman() {
    pkg "pixman"; local m="pixman-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://www.cairographics.org/releases/pixman-0.42.2.tar.gz" "pixman-0.42.2.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "pixman" "pixman-0.42.2" "$m" || return 0
    meson_build /usr -Dtests=disabled
    mark_done "$m"; cleanup_build
}

build_mesa() {
    pkg "mesa"; local m="mesa-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://mesa.freedesktop.org/archive/mesa-23.2.1.tar.xz" "mesa-23.2.1.tar.xz" || { error "  Download failed!"; return 1; }
    enter_build "mesa" "mesa-23.2.1" "$m" || return 0
    meson_build /usr \
        -Dgallium-drivers=swrast \
        -Dvulkan-drivers="" \
        -Dglvnd=false \
        -Dplatforms=x11,wayland \
        -Ddri3=false \
        -Dgallium-va=false \
        -Dgallium-vdpau=false \
        -Dllvm=false \
        -Dshared-llvm=false \
        -Dvalgrind=false \
        -Dlibunwind=false
    mark_done "$m"; cleanup_build
}

build_xkbcommon() {
    pkg "xkbcommon"; local m="xkbcommon-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.5.0.tar.gz" "xkbcommon-1.5.0.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "xkbcommon" "xkbcommon-1.5.0" "$m" || return 0
    meson_build /usr -Denable-docs=false -Denable-wayland=false -Denable-x11=false -Denable-tools=false
    mark_done "$m"; cleanup_build
}

build_seatd() {
    pkg "seatd"; local m="seatd-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://git.sr.ht/~kennylevinsen/seatd/archive/0.7.0.tar.gz" "seatd-0.7.0.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "seatd" "seatd-0.7.0" "$m" || return 0
    meson_build /usr -Dlibseat-builtin=enabled -Dlibseat-logind=disabled -Dlibseat-seatd=enabled
    mark_done "$m"; cleanup_build
}

build_wlroots() {
    pkg "wlroots"; local m="wlroots-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.16.2/wlroots-0.16.2.tar.gz" "wlroots-0.16.2.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "wlroots" "wlroots-0.16.2" "$m" || return 0
    meson_build /usr -Dexamples=false -Dxwayland=disabled
    mark_done "$m"; cleanup_build
}

build_hyprland() {
    pkg "Hyprland"; local m="hyprland-done"
    if is_done "$m"; then log "  Already done."; return 0; fi
    download "https://github.com/hyprwm/Hyprland/archive/refs/tags/v0.30.0.tar.gz" "Hyprland-0.30.0.tar.gz" || { error "  Download failed!"; return 1; }
    enter_build "Hyprland" "Hyprland-0.30.0" "$m" || return 0
    log "  Fetching submodules..."
    # Copy pre-cloned submodules from host (git clone doesn't work inside chroot)
    if [ ! -d subprojects/hyprland-protocols/protocols ]; then
        if [ -d /sources/hyprland-submods/hyprland-protocols ]; then
            cp -r /sources/hyprland-submods/hyprland-protocols/* subprojects/hyprland-protocols/ >> "$LOG_FILE" 2>&1
            log "    Copied hyprland-protocols from host"
        else
            git clone --depth=1 https://github.com/hyprwm/hyprland-protocols subprojects/hyprland-protocols >> "$LOG_FILE" 2>&1 || true
        fi
    fi
    if [ ! -f subprojects/udis86/CMakeLists.txt ]; then
        if [ -d /sources/hyprland-submods/udis86 ]; then
            cp -r /sources/hyprland-submods/udis86/* subprojects/udis86/ >> "$LOG_FILE" 2>&1
            log "    Copied udis86 from host"
        else
            git clone --depth=1 https://github.com/canihavesomecoffee/udis86 subprojects/udis86 >> "$LOG_FILE" 2>&1 || true
        fi
    fi
    rm -rf build
    mkdir -p build
    log "  Configuring (cmake)..."
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DLEGACY_RENDERER=ON \
        -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules \
        -DCMAKE_CXX_FLAGS="-std=gnu++20" \
        -DCMAKE_C_COMPILER=/usr/bin/gcc \
        -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
        >> "$LOG_FILE" 2>&1 || { error "  Configure failed!"; return 1; }
    log "  Building..."
    cmake --build build -j"$(nproc)" >> "$LOG_FILE" 2>&1 || { error "  Build failed!"; return 1; }
    log "  Installing..."
    cmake --install build >> "$LOG_FILE" 2>&1 || { error "  Install failed!"; return 1; }
    mark_done "$m"; cleanup_build
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║   HARAMchy Wayland/Hyprland Stack Build         ║"
    log "╚══════════════════════════════════════════════════╝"
    log ""

    local start_time; start_time=$(date +%s)
    local failed=()

    run() {
        local name="$1"; shift
        log ""
        if "$@"; then true; else failed+=("$name"); fi
    }

    run "wayland-protocols"  build_wayland_protocols
    run "wayland"            build_wayland
    run "libdrm"             build_libdrm
    run "pixman"             build_pixman
    run "mesa"               build_mesa
    run "xkbcommon"          build_xkbcommon
    run "seatd"              build_seatd
    run "wlroots"            build_wlroots
    run "hyprland"           build_hyprland

    local end_time; end_time=$(date +%s)
    local elapsed=$(( end_time - start_time ))
    local minutes=$(( elapsed / 60 ))
    local seconds=$(( elapsed % 60 ))

    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║   Wayland Stack Build Complete                  ║"
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
