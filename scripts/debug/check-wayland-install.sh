#!/bin/bash
echo 177695 | sudo -S bash -c '
echo "=== Find wayland 1.22 files ==="
find /usr -name "libwayland*" -type f 2>/dev/null
find /usr -name "libwayland*" -type l 2>/dev/null

echo ""
echo "=== Check /usr/lib64 ==="
ls -la /usr/lib64/libwayland* 2>/dev/null

echo ""
echo "=== Check wayland pkg-config ==="
pkg-config --libs wayland-server 2>/dev/null
pkg-config --libs-only-L wayland-server 2>/dev/null

echo ""
echo "=== Mesa log ==="
cat /home/lfs/lfs-root/tmp/build/mesa-23.2.1/build/meson-logs/meson-log.txt 2>/dev/null | tail -60
'
