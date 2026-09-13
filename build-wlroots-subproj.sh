#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Check subproject wlroots ==="
ls "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/meson.build" 2>/dev/null
ls "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/" 2>/dev/null | head -10

echo ""
echo "=== Build wlroots subproject inside chroot ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "cd /tmp/build/Hyprland-0.30.0/subprojects/wlroots && meson setup build --prefix=/usr -Dexamples=false -Dxwayland=disabled -Dtests=false 2>&1" | tail -20

echo ""
echo "=== Build wlroots ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build -j$(nproc) 2>&1" | tail -10

echo ""
echo "=== Check result ==="
ls -la "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots"* 2>/dev/null
'
