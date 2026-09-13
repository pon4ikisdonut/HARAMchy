#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Mesa meson-log full ==="
cat "$LFS/tmp/build/mesa-23.2.1/build/meson-logs/meson-log.txt" 2>/dev/null

echo ""
echo "=== xkbcommon build error in detail ==="
grep -B10 -A10 "error" "$LFS/var/log/haramchy-wayland.log" | grep -B5 -A5 "xkbcommon\|xkb-1\|xkbcommon-x11" | head -40
'
