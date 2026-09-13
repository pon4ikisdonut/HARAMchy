#!/bin/bash
set -e

echo "=== Rebuilding Hyprland 0.30.0 ==="

HYPRBUILD="/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0"

cd "$HYPRBUILD"
rm -rf build

export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
export PATH="/usr/bin:$PATH"
export CC=gcc
export CXX=g++-13

echo "Running meson setup..."
meson setup build \
    -Dxwayland=enabled \
    -Dsystemd=disabled \
    -Dlegacy_renderer=disabled \
    2>&1 | tail -40

# Fix: create wlr -> wlroots symlinks in build include dir for config.h
echo "Creating wlr -> wlroots symlinks..."
echo '177695' | sudo -S mkdir -p build/subprojects/wlroots/include/wlr
echo '177695' | sudo -S ln -sf /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/build/subprojects/wlroots/include/wlroots/config.h /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/build/subprojects/wlroots/include/wlr/config.h
echo '177695' | sudo -S ln -sf /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/build/subprojects/wlroots/include/wlroots/version.h /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/build/subprojects/wlroots/include/wlr/version.h

echo "Running ninja..."
ninja -C build 2>&1 | tail -80
echo "=== Hyprland build attempt finished ==="
