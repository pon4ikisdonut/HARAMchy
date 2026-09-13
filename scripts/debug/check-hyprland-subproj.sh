#!/bin/bash
echo 177695 | sudo -S bash -c '
echo "=== Re-extract Hyprland ==="
rm -rf /tmp/build/Hyprland-0.30.0
tar xf /home/lfs/src/Hyprland-0.30.0.tar.gz -C /tmp/build/
cd /tmp/build/Hyprland-0.30.0

echo "=== Clone submodules ==="
git clone --depth=1 https://github.com/hyprwm/hyprland-protocols subprojects/hyprland-protocols 2>&1 | tail -1
git clone --depth=1 https://github.com/canihavesomecoffee/udis86 subprojects/udis86 2>&1 | tail -1
git clone --depth=1 https://gitlab.freedesktop.org/wlroots/wlroots.git subprojects/wlroots 2>&1 | tail -1

echo "=== Check cursor_shape in Hyprland source ==="
grep -n "cursor_shape" src/includes.hpp 2>/dev/null

echo ""
echo "=== Check cursor_shape in subproject wlroots ==="
find subprojects/wlroots -name "*cursor_shape*" 2>/dev/null
grep -r "cursor_shape" subprojects/wlroots/include/ 2>/dev/null | head -5

echo ""
echo "=== Check Hyprland CMakeLists for cursor_shape ==="
grep -n "cursor_shape" CMakeLists.txt 2>/dev/null

echo ""
echo "=== Check wlroots include dir ==="
ls subprojects/wlroots/include/wlr/types/ 2>/dev/null | head -30
'
