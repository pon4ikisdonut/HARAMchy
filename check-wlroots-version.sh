#!/bin/bash
echo 177695 | sudo -S bash -c '
HL=/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0

echo "=== Check Hyprland wlroots commit ==="
cd "$HL"
# The .gitmodules just says wlroots.git, check git submodule status
git ls-tree HEAD subprojects/ 2>/dev/null

echo ""
echo "=== Check git tags in subproject wlroots ==="
cd "$HL/subprojects/wlroots"
git log --oneline -3 2>/dev/null
git describe --tags 2>/dev/null

echo ""
echo "=== Does 0.16.2 have cursor_shape? ==="
find "$HL/subprojects/wlroots" -name "*cursor_shape*" 2>/dev/null

echo ""
echo "=== Check wlroots meson options ==="
cat "$HL/subprojects/wlroots/meson_options.txt" 2>/dev/null
'
