#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

# Fix wayland version to 1.22.0 in all pkg-config files
for dir in /usr/lib/x86_64-linux-gnu/pkgconfig /usr/lib/pkgconfig; do
    for f in "$dir"/wayland-*.pc; do
        [ -f "$f" ] || continue
        sed -i "s/^Version:.*/Version: 1.22.0/" "$f"
        echo "Fixed: $f"
    done
done

# Also fix in chroot
for dir in "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig"; do
    mkdir -p "$dir" 2>/dev/null
    for f in "$dir"/wayland-*.pc; do
        [ -f "$f" ] || continue
        sed -i "s/^Version:.*/Version: 1.22.0/" "$f"
        echo "Fixed: $f"
    done
done

echo "=== Verify ==="
pkg-config --modversion wayland-server
pkg-config --modversion wayland-client

echo "=== Fix Hyprland source permissions ==="
chmod -R a+w /tmp/Hyprland-0.30.0 2>/dev/null
chown -R root:root /tmp/Hyprland-0.30.0 2>/dev/null
'
