#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

cp -f /usr/include/xcb/*.h "$LFS/usr/include/xcb/" 2>/dev/null
echo "xcb headers: $(ls "$LFS/usr/include/xcb/xcb_ewmh.h" 2>/dev/null)"

ln -sf libwlroots.so.12 "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots.so.12032" 2>/dev/null
echo "wlroots symlink: $(ls "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots.so.12032" 2>/dev/null)"

for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
