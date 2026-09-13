#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy built libdrm 2.4.120 to x86_64-linux-gnu ==="
cp -f "$LFS/usr/lib64/libdrm.so.2.4.120" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libdrm.so.2" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libdrm.so" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libdrm_amdgpu.so"* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libdrm_intel.so"* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libdrm_nouveau.so"* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libdrm_radeon.so"* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null

echo "=== Verify ==="
ls -la "$LFS/usr/lib/x86_64-linux-gnu/libdrm.so"* 2>/dev/null

echo ""
echo "=== Rebuild wlroots 0.17.1 ==="
rm -rf "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "cd /tmp/build/Hyprland-0.30.0/subprojects/wlroots && meson setup build --prefix=/usr -Dexamples=false -Dxwayland=disabled 2>&1" | tail -5

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build -j$(nproc) 2>&1" | tail -5

echo ""
echo "=== Install wlroots ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build install 2>&1" | tail -5

echo ""
echo "=== Check result ==="
ls -la "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots"* 2>/dev/null
ls "$LFS/usr/include/wlr/types/wlr_cursor_shape_v1.h" 2>/dev/null
'
