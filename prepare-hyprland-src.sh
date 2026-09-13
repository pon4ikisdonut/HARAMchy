#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
BUILD=/tmp/build

echo "=== Extract Hyprland ==="
rm -rf "$BUILD/Hyprland-0.30.0"
mkdir -p "$BUILD"
tar xf /home/lfs/src/Hyprland-0.30.0.tar.gz -C "$BUILD"

cd "$BUILD/Hyprland-0.30.0"

echo "=== Clone submodules ==="
git clone --depth=1 https://github.com/hyprwm/hyprland-protocols subprojects/hyprland-protocols 2>&1
git clone --depth=1 https://github.com/canihavesomecoffee/udis86 subprojects/udis86 2>&1
git clone --depth=1 https://gitlab.freedesktop.org/wlroots/wlroots.git subprojects/wlroots 2>&1

echo "=== Fix permissions ==="
chmod -R a+w "$BUILD/Hyprland-0.30.0"

echo "=== Verify ==="
ls subprojects/hyprland-protocols/protocols/hyprland-global-shortcuts-v1.xml
ls subprojects/wlroots/meson.build
ls subprojects/udis86/CMakeLists.txt

echo "=== Done ==="
'
