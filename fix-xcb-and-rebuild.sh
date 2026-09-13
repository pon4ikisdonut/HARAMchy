#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy xcb headers ==="
cp -r /usr/include/xcb "$LFS/usr/include/" 2>/dev/null
echo "  Copied xcb headers"

echo "=== Copy libxcb-ewmh ==="
cp -f /usr/lib/x86_64-linux-gnu/libxcb-ewmh.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-composite.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-render.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-shm.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-xfixes.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-present.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-dri3.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-render-util.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-dri2.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxcb-xinput.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null

echo "=== Copy pkg-config files for xcb ==="
for f in /usr/lib/x86_64-linux-gnu/pkgconfig/xcb*.pc; do
    cp -f "$f" "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
    cp -f "$f" "$LFS/usr/lib/pkgconfig/" 2>/dev/null
done

echo "=== Install xkbcommon via build script ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash -c "
cd /sources
ls xkbcommon*.tar.gz 2>/dev/null || echo xkbcommon tarball not found in /sources
ls /sources/ | grep xkb 2>/dev/null
" 2>&1

echo "=== Check sources mount ==="
ls "$LFS/sources/" 2>/dev/null | head -10

echo "=== Try xkbcommon build ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash -c "
cd /tmp
tar xf /sources/xkbcommon-1.5.0.tar.gz 2>/dev/null || tar xf /home/lfs/src/xkbcommon-1.5.0.tar.gz 2>/dev/null || echo FAILED
ls /tmp/libxkbcommon* 2>/dev/null
" 2>&1
'
