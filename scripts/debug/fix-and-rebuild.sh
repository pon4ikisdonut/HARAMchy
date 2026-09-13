#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Mount sources ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

echo "=== Copy bison m4sugar data ==="
mkdir -p "$LFS/usr/share/bison"
cp -r /usr/share/bison/* "$LFS/usr/share/bison/" 2>/dev/null

echo "=== Copy wayland 1.22 libs from chroot /usr/lib64 to /usr/lib/x86_64-linux-gnu ==="
# The built wayland 1.22 installed to /usr/lib64 inside chroot
# Linker searches /usr/lib/x86_64-linux-gnu so we need the 1.22 libs there
for lib in libwayland-server libwayland-client libwayland-cursor libwayland-egl; do
    src=$(ls "$LFS/usr/lib64/${lib}.so.0.22.0" 2>/dev/null || ls "$LFS/usr/lib64/${lib}.so.1.22.0" 2>/dev/null)
    if [ -n "$src" ]; then
        bn=$(basename "$src")
        echo "  Copying $bn"
        cp -f "$src" "$LFS/usr/lib/x86_64-linux-gnu/$bn"
    fi
done
# Update symlinks
rm -f "$LFS/usr/lib/x86_64-linux-gnu/libwayland-server.so" "$LFS/usr/lib/x86_64-linux-gnu/libwayland-server.so.0"
ln -sf libwayland-server.so.0.22.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-server.so.0"
ln -sf libwayland-server.so.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-server.so"
rm -f "$LFS/usr/lib/x86_64-linux-gnu/libwayland-client.so" "$LFS/usr/lib/x86_64-linux-gnu/libwayland-client.so.0"
ln -sf libwayland-client.so.0.22.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-client.so.0"
ln -sf libwayland-client.so.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-client.so"
rm -f "$LFS/usr/lib/x86_64-linux-gnu/libwayland-cursor.so" "$LFS/usr/lib/x86_64-linux-gnu/libwayland-cursor.so.0"
ln -sf libwayland-cursor.so.0.22.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-cursor.so.0"
ln -sf libwayland-cursor.so.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-cursor.so"
rm -f "$LFS/usr/lib/x86_64-linux-gnu/libwayland-egl.so" "$LFS/usr/lib/x86_64-linux-gnu/libwayland-egl.so.1"
ln -sf libwayland-egl.so.1.22.0 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-egl.so.1"
ln -sf libwayland-egl.so.1 "$LFS/usr/lib/x86_64-linux-gnu/libwayland-egl.so"

echo "=== Also copy to /usr/lib64 symlinks ==="
for lib in libwayland-server libwayland-client libwayland-cursor libwayland-egl; do
    src=$(ls "$LFS/usr/lib64/${lib}.so.0.22.0" 2>/dev/null || ls "$LFS/usr/lib64/${lib}.so.1.22.0" 2>/dev/null)
    if [ -n "$src" ]; then
        bn=$(basename "$src")
        cp -f "$src" "$LFS/usr/lib/x86_64-linux-gnu/$bn"
    fi
done
rm -f "$LFS/usr/lib64/libwayland-server.so" "$LFS/usr/lib64/libwayland-server.so.0"
ln -sf libwayland-server.so.0.22.0 "$LFS/usr/lib64/libwayland-server.so.0"
ln -sf libwayland-server.so.0 "$LFS/usr/lib64/libwayland-server.so"
rm -f "$LFS/usr/lib64/libwayland-client.so" "$LFS/usr/lib64/libwayland-client.so.0"
ln -sf libwayland-client.so.0.22.0 "$LFS/usr/lib64/libwayland-client.so.0"
ln -sf libwayland-client.so.0 "$LFS/usr/lib64/libwayland-client.so"
rm -f "$LFS/usr/lib64/libwayland-cursor.so" "$LFS/usr/lib64/libwayland-cursor.so.0"
ln -sf libwayland-cursor.so.0.22.0 "$LFS/usr/lib64/libwayland-cursor.so.0"
ln -sf libwayland-cursor.so.0 "$LFS/usr/lib64/libwayland-cursor.so"
rm -f "$LFS/usr/lib64/libwayland-egl.so" "$LFS/usr/lib64/libwayland-egl.so.1"
ln -sf libwayland-egl.so.1.22.0 "$LFS/usr/lib64/libwayland-egl.so.1"
ln -sf libwayland-egl.so.1 "$LFS/usr/lib64/libwayland-egl.so"

echo "=== Verify wayland version ==="
ls -la "$LFS/usr/lib/x86_64-linux-gnu/libwayland-server.so"* 2>/dev/null

echo "=== Clear only failed markers ==="
rm -f "$LFS/home/lfs/.build-markers/wayland/mesa-done"
rm -f "$LFS/home/lfs/.build-markers/wayland/xkbcommon-done"
rm -f "$LFS/home/lfs/.build-markers/wayland/wlroots-done"
rm -f "$LFS/home/lfs/.build-markers/wayland/hyprland-done"

echo "=== Run build ==="
cp /mnt/e/projects/haramchy/build-wayland-stack.sh "$LFS/home/lfs/build-wayland-stack.sh"
chmod +x "$LFS/home/lfs/build-wayland-stack.sh"
mkdir -p "$LFS/tmp/build"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash /home/lfs/build-wayland-stack.sh 2>&1

for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
