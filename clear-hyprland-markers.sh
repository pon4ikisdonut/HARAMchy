#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
M="$LFS/home/lfs/.build-markers/wayland"

echo "=== Clear failed markers ==="
rm -f "$M/hyprland-done" "$M/wlroots-done" "$M/wayland-done" "$M/libinput-done"

echo "=== Fix source permissions ==="
chmod -R a+w /tmp/Hyprland-0.30.0 2>/dev/null
chmod -R a+w /tmp/hyprland-protocols-main 2>/dev/null
chmod -R a+w /tmp/udis86-main 2>/dev/null

# Fix inside Hyprland subprojects
chmod -R a+w /tmp/Hyprland-0.30.0/subprojects/hyprland-protocols 2>/dev/null
chmod -R a+w /tmp/Hyprland-0.30.0/subprojects/udis86 2>/dev/null
chmod -R a+w /tmp/Hyprland-0.30.0/subprojects/wlroots 2>/dev/null
chmod -R a+w /tmp/Hyprland-0.30.0/build 2>/dev/null

echo "=== Fix udis86 ==="
cd /tmp/Hyprland-0.30.0/subprojects/udis86
# Clone fresh if empty
if [ ! -f Makefile ]; then
    rm -rf /tmp/Hyprland-0.30.0/subprojects/udis86
    git clone --depth=1 https://github.com/canihavesomecoffee/udis86 /tmp/Hyprland-0.30.0/subprojects/udis86
fi
make -j$(nproc) 2>&1 | tail -3

echo "=== Verify wayland version ==="
pkg-config --modversion wayland-server

echo "=== Remaining markers ==="
ls -la "$M/"
'
