#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
HL="$LFS/tmp/build/Hyprland-0.30.0"

echo "=== Build wlroots 0.17.1 ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build -j$(nproc) 2>&1" | tail -15

echo ""
echo "=== Check result ==="
ls -la "$HL/subprojects/wlroots/build/libwlroots"* 2>/dev/null

echo ""
echo "=== Install wlroots ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build install 2>&1" | tail -5

echo ""
echo "=== Check cursor_shape header installed ==="
ls "$LFS/usr/include/wlr/types/wlr_cursor_shape_v1.h" 2>/dev/null

echo ""
echo "=== Check libwlroots soname ==="
ls -la "$LFS/usr/lib64/libwlroots"* 2>/dev/null
ls -la "$LFS/usr/lib/x86_64-linux-gnu/libwlroots"* 2>/dev/null
'
