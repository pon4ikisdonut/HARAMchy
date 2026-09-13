#!/bin/bash
# ============================================
# HARAMchy Linux - Hyprland + Wayland Stack Build
# ============================================
# Builds the complete Wayland/Hyprland stack from source
# ============================================

set -euo pipefail

# ============================================
# Configuration
# ============================================

BUILD_DIR="/home/lfs/build"
LFS_ROOT="/home/lfs/lfs-root"
PKG_CONFIG_PATH="$LFS_ROOT/usr/lib/pkgconfig:$LFS_ROOT/usr/share/pkgconfig"
LD_LIBRARY_PATH="$LFS_ROOT/usr/lib:$LD_LIBRARY_PATH"
LOG_FILE="/home/lfs/hyprland-build.log"

WAYLAND_VERSION="1.22.0"
WAYLAND_PROTOCOLS_VERSION="1.33"
LIBINPUT_VERSION="1.24.0"
LIBXKBCOMMON_VERSION="1.5.0"
WLROOTS_VERSION="0.17.0"
HYPRLAND_VERSION="0.33.1"
XDG_PORTAL_VERSION="0.5.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
TEAL='\033[0;36m'
NC='\033[0m'

log()      { echo -e "${TEAL}[WAYLAND]${NC} $1" | tee -a "$LOG_FILE"; }
success()  { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
warn()     { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error()    { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# ============================================
# Prerequisites Check
# ============================================

check_prerequisites() {
    log "Checking prerequisites..."

    for cmd in gcc meson cmake ninja git; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Required command not found: $cmd"
        fi
    done

    if [ ! -d "$LFS_ROOT" ]; then
        error "LFS root not found at $LFS_ROOT"
    fi

    success "Prerequisites OK"
}

# ============================================
# Download Helper
# ============================================

download_source() {
    local name="$1"
    local url="$2"
    local version="$3"
    local ext="${4:-.tar.xz}"

    local tarball="$BUILD_DIR/${name}-${version}${ext}"
    local dir="$BUILD_DIR/${name}-${version}"

    if [ -d "$dir" ]; then
        log "$name already extracted, skipping download"
        return 0
    fi

    log "Downloading $name $version..."
    wget -q --show-progress -O "$tarball" "$url" \
        >> "$LOG_FILE" 2>&1 || error "Failed to download $name"

    log "Extracting $name..."
    tar -xf "$tarball" -C "$BUILD_DIR" \
        >> "$LOG_FILE" 2>&1 || error "Failed to extract $name"

    rm -f "$tarball"
    success "$name $version ready"
}

# ============================================
# Build wayland-protocols
# ============================================

build_wayland_protocols() {
    log "Building wayland-protocols ${WAYLAND_PROTOCOLS_VERSION}..."

    download_source "wayland-protocols" \
        "https://wayland.freedesktop.org/releases/wayland-protocols-${WAYLAND_PROTOCOLS_VERSION}.tar.xz" \
        "$WAYLAND_PROTOCOLS_VERSION"

    cd "$BUILD_DIR/wayland-protocols-${WAYLAND_PROTOCOLS_VERSION}"

    meson setup build --prefix="$LFS_ROOT/usr" \
        --default-library=both \
        -Dtests=false \
        >> "$LOG_FILE" 2>&1 || error "wayland-protocols meson setup failed"

    ninja -C build >> "$LOG_FILE" 2>&1 || error "wayland-protocols build failed"

    ninja -C build install >> "$LOG_FILE" 2>&1 || error "wayland-protocols install failed"

    success "wayland-protocols installed"
}

# ============================================
# Build libinput
# ============================================

build_libinput() {
    log "Building libinput ${LIBINPUT_VERSION}..."

    download_source "libinput" \
        "https://www.freedesktop.org/software/libinput/libinput-${LIBINPUT_VERSION}.tar.xz" \
        "$LIBINPUT_VERSION"

    cd "$BUILD_DIR/libinput-${LIBINPUT_VERSION}"

    meson setup build --prefix="$LFS_ROOT/usr" \
        --default-library=both \
        -Dtests=false \
        -Dlibwacom=false \
        -Ddocumentation=false \
        -Ddebug-gui=false \
        >> "$LOG_FILE" 2>&1 || error "libinput meson setup failed"

    ninja -C build >> "$LOG_FILE" 2>&1 || error "libinput build failed"

    ninja -C build install >> "$LOG_FILE" 2>&1 || error "libinput install failed"

    success "libinput installed"
}

# ============================================
# Build libxkbcommon
# ============================================

build_libxkbcommon() {
    log "Building libxkbcommon ${LIBXKBCOMMON_VERSION}..."

    download_source "libxkbcommon" \
        "https://xkbcommon.org/download/libxkbcommon-${LIBXKBCOMMON_VERSION}.tar.xz" \
        "$LIBXKBCOMMON_VERSION"

    cd "$BUILD_DIR/libxkbcommon-${LIBXKBCOMMON_VERSION}"

    meson setup build --prefix="$LFS_ROOT/usr" \
        --default-library=both \
        -Denable-docs=false \
        -Denable-wayland-scanner=true \
        -Denable-x11=false \
        >> "$LOG_FILE" 2>&1 || error "libxkbcommon meson setup failed"

    ninja -C build >> "$LOG_FILE" 2>&1 || error "libxkbcommon build failed"

    ninja -C build install >> "$LOG_FILE" 2>&1 || error "libxkbcommon install failed"

    success "libxkbcommon installed"
}

# ============================================
# Build wayland
# ============================================

build_wayland() {
    log "Building wayland ${WAYLAND_VERSION}..."

    download_source "wayland" \
        "https://wayland.freedesktop.org/releases/wayland-${WAYLAND_VERSION}.tar.xz" \
        "$WAYLAND_VERSION"

    cd "$BUILD_DIR/wayland-${WAYLAND_VERSION}"

    meson setup build --prefix="$LFS_ROOT/usr" \
        --default-library=both \
        -Dtests=false \
        -Ddocumentation=false \
        -Dscanner=true \
        >> "$LOG_FILE" 2>&1 || error "wayland meson setup failed"

    ninja -C build >> "$LOG_FILE" 2>&1 || error "wayland build failed"

    ninja -C build install >> "$LOG_FILE" 2>&1 || error "wayland install failed"

    success "wayland installed"
}

# ============================================
# Build wlroots
# ============================================

build_wlroots() {
    log "Building wlroots ${WLROOTS_VERSION}..."

    download_source "wlroots" \
        "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/${WLROOTS_VERSION}/wlroots-${WLROOTS_VERSION}.tar.gz" \
        "$WLROOTS_VERSION" \
        ".tar.gz"

    cd "$BUILD_DIR/wlroots-${WLROOTS_VERSION}"

    meson setup build --prefix="$LFS_ROOT/usr" \
        --default-library=both \
        -Dexamples=false \
        -Dxwayland=enabled \
        -Dbackends=drm,libinput \
        >> "$LOG_FILE" 2>&1 || error "wlroots meson setup failed"

    ninja -C build >> "$LOG_FILE" 2>&1 || error "wlroots build failed"

    ninja -C build install >> "$LOG_FILE" 2>&1 || error "wlroots install failed"

    success "wlroots installed"
}

# ============================================
# Build Hyprland
# ============================================

build_hyprland() {
    log "Building Hyprland ${HYPRLAND_VERSION}..."

    download_source "hyprland" \
        "https://github.com/hyprwm/Hyprland/releases/download/v${HYPRLAND_VERSION}/source-v${HYPRLAND_VERSION}.tar.gz" \
        "$HYPRLAND_VERSION" \
        ".tar.gz"

    cd "$BUILD_DIR/hyprland-${HYPRLAND_VERSION}"

    export PKG_CONFIG_PATH="$LFS_ROOT/usr/lib/pkgconfig:$LFS_ROOT/usr/share/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$LFS_ROOT/usr/lib:$LD_LIBRARY_PATH"
    export PATH="$LFS_ROOT/usr/bin:$PATH"

    make all -j$(nproc) \
        PREFIX="$LFS_ROOT/usr" \
        >> "$LOG_FILE" 2>&1 || error "Hyprland build failed"

    make install PREFIX="$LFS_ROOT/usr" \
        >> "$LOG_FILE" 2>&1 || error "Hyprland install failed"

    # Install hyprpaper
    if [ -f "$BUILD_DIR/hyprland-${HYPRLAND_VERSION}/subprojects/hyprpaper" ] || \
       [ -d "$BUILD_DIR/hyprland-${HYPRLAND_VERSION}/subprojects" ]; then
        log "Hyprland subprojects installed"
    fi

    success "Hyprland installed"
}

# ============================================
# Build xdg-desktop-portal-hyprland
# ============================================

build_xdg_portal() {
    log "Building xdg-desktop-portal-hyprland..."

    if [ -d "$BUILD_DIR/xdg-desktop-portal-hyprland" ]; then
        cd "$BUILD_DIR/xdg-desktop-portal-hyprland"
        git pull >> "$LOG_FILE" 2>&1 || true
    else
        git clone https://github.com/hyprwm/xdg-desktop-portal-hyprland.git \
            "$BUILD_DIR/xdg-desktop-portal-hyprland" \
            >> "$LOG_FILE" 2>&1 || error "Failed to clone xdg-desktop-portal-hyprland"
        cd "$BUILD_DIR/xdg-desktop-portal-hyprland"
        git checkout "v${XDG_PORTAL_VERSION}" >> "$LOG_FILE" 2>&1 || true
    fi

    export PKG_CONFIG_PATH="$LFS_ROOT/usr/lib/pkgconfig:$LFS_ROOT/usr/share/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="$LFS_ROOT/usr/lib:$LD_LIBRARY_PATH"
    export PATH="$LFS_ROOT/usr/bin:$PATH"

    meson setup build --prefix="$LFS_ROOT/usr" \
        --default-library=both \
        >> "$LOG_FILE" 2>&1 || error "xdg-portal meson setup failed"

    ninja -C build >> "$LOG_FILE" 2>&1 || error "xdg-portal build failed"

    ninja -C build install >> "$LOG_FILE" 2>&1 || error "xdg-portal install failed"

    success "xdg-desktop-portal-hyprland installed"
}

# ============================================
# Install Hyprland Dotfiles
# ============================================

install_dotfiles() {
    log "Installing Hyprland dotfiles..."

    local dotfiles_dir="$(dirname "$0")/../../hyprland-dots"

    if [ -d "$dotfiles_dir" ]; then
        mkdir -p "$LFS_ROOT/etc/skel/.config/hypr"
        mkdir -p "$LFS_ROOT/etc/skel/.config/waybar"
        mkdir -p "$LFS_ROOT/etc/skel/.config/alacritty"

        cp "$dotfiles_dir/hyprland.conf" "$LFS_ROOT/etc/skel/.config/hypr/hyprland.conf"
        cp "$dotfiles_dir/waybar/config.jsonc" "$LFS_ROOT/etc/skel/.config/waybar/config.jsonc"
        cp "$dotfiles_dir/waybar/style.css" "$LFS_ROOT/etc/skel/.config/waybar/style.css"
        cp "$dotfiles_dir/alacritty.toml" "$LFS_ROOT/etc/skel/.config/alacritty/alacritty.toml"
        cp "$dotfiles_dir/hyprpaper.conf" "$LFS_ROOT/etc/skel/.config/hypr/hyprpaper.conf"

        # Create autostart directory
        mkdir -p "$LFS_ROOT/etc/skel/.config/hypr/autostart"

        success "Hyprland dotfiles installed"
    else
        warn "Dotfiles directory not found, skipping dotfile installation"
    fi
}

# ============================================
# Cleanup
# ============================================

cleanup() {
    log "Cleaning up build directories..."

    rm -rf "$BUILD_DIR/wayland-${WAYLAND_VERSION}"
    rm -rf "$BUILD_DIR/wayland-protocols-${WAYLAND_PROTOCOLS_VERSION}"
    rm -rf "$BUILD_DIR/libinput-${LIBINPUT_VERSION}"
    rm -rf "$BUILD_DIR/libxkbcommon-${LIBXKBCOMMON_VERSION}"
    rm -rf "$BUILD_DIR/wlroots-${WLROOTS_VERSION}"
    rm -rf "$BUILD_DIR/hyprland-${HYPRLAND_VERSION}"

    success "Cleanup complete"
}

# ============================================
# Main
# ============================================

main() {
    echo ""
    echo -e "${TEAL}╔═══════════════════════════════════════╗${NC}"
    echo -e "${TEAL}║  HARAMchy Hyprland Stack Builder      ║${NC}"
    echo -e "${TEAL}╚═══════════════════════════════════════╝${NC}"
    echo ""

    : > "$LOG_FILE"

    check_prerequisites
    build_wayland_protocols
    build_libinput
    build_libxkbcommon
    build_wayland
    build_wlroots
    build_hyprland
    build_xdg_portal
    install_dotfiles
    cleanup

    echo ""
    success "Hyprland stack build complete!"
    log "Installed to: $LFS_ROOT/usr/"
    echo ""
}

main "$@"
