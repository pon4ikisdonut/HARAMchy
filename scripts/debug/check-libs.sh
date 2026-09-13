#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Actual wayland libraries ==="
ls -la /usr/lib/x86_64-linux-gnu/libwayland-server.so* 2>/dev/null
ls -la "$LFS/usr/lib/x86_64-linux-gnu/libwayland-server.so"* 2>/dev/null

echo ""
echo "=== Where did wayland 1.22 install? ==="
find /usr -name "libwayland-server*" -type f 2>/dev/null
find /usr -name "libwayland-client*" -type f 2>/dev/null

echo ""
echo "=== Mesa meson-log tail ==="
tail -40 "$LFS/tmp/build/mesa-23.2.1/build/meson-logs/meson-log.txt" 2>/dev/null

echo ""
echo "=== xkbcommon build error ==="
grep -B2 -A5 "error" "$LFS/var/log/haramchy-wayland.log" 2>/dev/null | grep -B2 -A5 "xkbcommon\|xkb" | head -30
'
