#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copying pkg-config ==="
cp -f /usr/bin/pkg-config "$LFS/usr/bin/pkg-config"
cp -f /usr/share/aclocal/pkg.m4 "$LFS/usr/share/aclocal/pkg.m4" 2>/dev/null

echo "=== Copying libbsd ==="
# Headers
mkdir -p "$LFS/usr/include/bsd"
cp -r /usr/include/bsd/* "$LFS/usr/include/bsd/" 2>/dev/null
# Library
cp -f /lib/x86_64-linux-gnu/libbsd.so* "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libbsd.so* "$LFS/lib64/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libbsd.a "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libbsd.a "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
# libmd (dependency of libbsd)
cp -f /lib/x86_64-linux-gnu/libmd.so* "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libmd.so* "$LFS/lib64/" 2>/dev/null

# pkg.m4
mkdir -p "$LFS/usr/share/aclocal"
cp -f /usr/share/aclocal/pkg.m4 "$LFS/usr/share/aclocal/" 2>/dev/null

echo "=== Copy pkg-config data ==="
cp -r /usr/lib/x86_64-linux-gnu/pkgconfig/libbsd.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
mkdir -p "$LFS/usr/lib/pkgconfig"
cp -r /usr/lib/x86_64-linux-gnu/pkgconfig/libbsd.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null

# Also need libbsd-bsd.h which provides strlcpy
echo "=== Verify ==="
ls "$LFS/usr/include/bsd/" 2>&1
ls "$LFS/lib/x86_64-linux-gnu/libbsd"* 2>&1
ldd "$LFS/usr/bin/pkg-config" 2>&1 | grep "not found" || echo "pkg-config OK"
'
