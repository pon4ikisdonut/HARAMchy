#!/bin/bash
echo 177695 | sudo -S bash -c '
HL=/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0

echo "=== Check Hyprland CMakeLists for wlroots version ==="
grep -i "wlroots\|version" "$HL/CMakeLists.txt" | head -20

echo ""
echo "=== Check Hyprland 0.30.0 release notes ==="
cat "$HL/README.md" 2>/dev/null | head -30

echo ""
echo "=== Check git tags ==="
cd "$HL"
# The git repo for Hyprland itself
git log --oneline -1 2>/dev/null
git tag -l "v0.3*" 2>/dev/null

echo ""
echo "=== Check what wlroots version Hyprland 0.30.0 gitmodules says ==="
cat "$HL/.gitmodules" 2>/dev/null

echo ""
echo "=== Remove the failed build dir ==="
rm -rf "$HL/subprojects/wlroots/build"
'
