#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
HL="$LFS/tmp/build/Hyprland-0.30.0"

echo "=== Re-clone wlroots at correct version ==="
rm -rf "$HL/subprojects/wlroots"
git clone --depth=1 --branch 0.16.2 https://gitlab.freedesktop.org/wlroots/wlroots.git "$HL/subprojects/wlroots" 2>&1 | tail -5
chmod -R a+w "$HL/subprojects/wlroots"

echo ""
echo "=== Verify cursor_shape ==="
ls "$HL/subprojects/wlroots/include/wlr/types/wlr_cursor_shape_v1.h" 2>/dev/null
ls "$HL/subprojects/wlroots/meson.build" 2>/dev/null

echo ""
echo "=== Build wlroots subproject ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "cd /tmp/build/Hyprland-0.30.0/subprojects/wlroots && rm -rf build && meson setup build --prefix=/usr -Dexamples=false -Dxwayland=disabled -Dtests=false 2>&1" | tail -10

echo ""
echo "=== Build wlroots ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build -j$(nproc) 2>&1" | tail -5

echo ""
echo "=== Check result ==="
ls -la "$HL/subprojects/wlroots/build/libwlroots"* 2>/dev/null
'
