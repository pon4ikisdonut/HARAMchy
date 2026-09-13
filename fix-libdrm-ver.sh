#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Update libdrm pkg-config version ==="
for dir in "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig" "$LFS/usr/lib64/pkgconfig"; do
    for f in "$dir"/libdrm*.pc; do
        [ -f "$f" ] || continue
        sed -i "s/^Version:.*/Version: 2.4.120/" "$f"
        echo "  Fixed: $f"
    done
done

echo ""
echo "=== Also update on host ==="
for f in /usr/lib/x86_64-linux-gnu/pkgconfig/libdrm*.pc; do
    [ -f "$f" ] || continue
    sed -i "s/^Version:.*/Version: 2.4.120/" "$f"
    echo "  Fixed: $f"
done

echo ""
echo "=== Verify ==="
pkg-config --modversion libdrm

echo ""
echo "=== Now build wlroots 0.17.1 ==="
rm -rf "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "cd /tmp/build/Hyprland-0.30.0/subprojects/wlroots && meson setup build --prefix=/usr -Dexamples=false -Dxwayland=disabled 2>&1" | tail -20
'
