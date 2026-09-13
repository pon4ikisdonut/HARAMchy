#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Chroot wayland libraries ==="
find "$LFS/usr" -name "libwayland*" -type f 2>/dev/null
find "$LFS/usr" -name "libwayland*" -type l 2>/dev/null

echo ""
echo "=== Mesa log in chroot ==="
cat "$LFS/tmp/build/mesa-23.2.1/build/meson-logs/meson-log.txt" 2>/dev/null | grep -i "error\|ERROR\|not found\|NOT FOUND" | head -20

echo ""
echo "=== xkbcommon build errors ==="
cat "$LFS/var/log/haramchy-wayland.log" 2>/dev/null | grep -B5 "error:" | grep -v "^--" | head -30
'
