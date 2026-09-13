#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy ALL host pkg-config files ==="
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig" "$LFS/usr/share/pkgconfig"
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
cp -f /usr/share/pkgconfig/*.pc "$LFS/usr/share/pkgconfig/" 2>/dev/null
echo "  pkg-config files: $(ls "$LFS/usr/lib/pkgconfig/"*.pc 2>/dev/null | wc -l)"

echo "=== Copy ncurses ==="
cp -f /lib/x86_64-linux-gnu/libncurses*.so* "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libncurses*.so* "$LFS/lib64/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libtinfo*.so* "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libtinfo*.so* "$LFS/lib64/" 2>/dev/null

echo "=== Copy awk + cmp ==="
cp -f /usr/bin/gawk "$LFS/usr/bin/gawk" 2>/dev/null
cp -f /usr/bin/gawk "$LFS/usr/bin/awk" 2>/dev/null
cp -f /usr/bin/gawk "$LFS/usr/bin/mawk" 2>/dev/null
cp -f /usr/bin/cmp "$LFS/usr/bin/cmp" 2>/dev/null
echo "  gawk/awk/cmp"

echo "=== Verify ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /usr/bin/pkg-config --list-all 2>&1 | grep -E "libbsd|ncurses" | head -5
'
