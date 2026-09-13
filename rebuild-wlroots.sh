#!/bin/bash
set -e

echo "=== Rebuilding wlroots at correct commit for Hyprland 0.30.0 ==="

HYPRBUILD="/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0"
WLROOTS_DIR="$HYPRBUILD/subprojects/wlroots"
PATCH="$HYPRBUILD/subprojects/packagefiles/wlroots-meson-build.patch"
REQUIRED_COMMIT="98a745d926d8048bc30aef11b421df207a01c279"

# Remove old wlroots
rm -rf "$WLROOTS_DIR"

# Clone wlroots (full clone, then checkout specific commit)
echo "Cloning wlroots..."
cd "$HYPRBUILD/subprojects"
git clone https://gitlab.freedesktop.org/wlroots/wlroots.git wlroots 2>&1
cd wlroots
echo "Checking out $REQUIRED_COMMIT..."
git checkout "$REQUIRED_COMMIT" 2>&1
cd ..

# Apply patch
echo "Applying wlroots meson build patch..."
cd wlroots
git apply "$PATCH" 2>&1 || patch -p1 < "$PATCH" 2>&1
cd ..

# Build Hyprland
echo "Building Hyprland..."
cd "$HYPRBUILD"
rm -rf build
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
export PATH="/usr/bin:$PATH"

meson setup build \
    -Dwayland-session-dir=/usr/share/wayland-sessions \
    -Dxwayland=enabled \
    2>&1 | tail -40

ninja -C build 2>&1 | tail -50
echo "=== wlroots + Hyprland build attempt finished ==="
