#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Step 1: Replace headers with host-consistent set ==="
rm -rf "$LFS/usr/include.bak"
mv "$LFS/usr/include" "$LFS/usr/include.bak" 2>/dev/null
cp -r /usr/include "$LFS/usr/include"

# Restore Linux kernel headers
for dir in linux asm asm-generic asm-x86; do
    [ -d "$LFS/usr/include.bak/$dir" ] && cp -r "$LFS/usr/include.bak/$dir" "$LFS/usr/include/" 2>/dev/null
done
rm -rf "$LFS/usr/include.bak" 2>/dev/null

echo "=== Step 2: Copy ALL host shared libs ==="
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
for src in /lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib64/$bn" 2>/dev/null
done
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu"
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null

echo "=== Step 3: Fix dangling symlinks ==="
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then rm -f "$link"; cp -f "$real" "$link" 2>/dev/null; fi
    fi
done

echo "=== Step 4: Copy essential host binaries ==="
for tool in echo mktemp cat ls chmod chown date dd head install ln mkdir mknod mkfifo rm rmdir tail touch env nproc seq test timeout truncate wc arch basename comm cut dirname expand fmt fold id join logname md5sum nice nohup od paste pr printenv readlink realpath shuf sort tac tee tr tsort uniq unlink which find xargs diff file gawk awk mawk nawk cmp pkg-config ld as ar objcopy objdump ranlib nm strip readelf; do
    src=$(which "$tool" 2>/dev/null)
    if [ -n "$src" ] && [ -f "$src" ]; then
        cp -f "$src" "$LFS/usr/bin/$tool" 2>/dev/null
    fi
done

echo "=== Step 5: Copy pkg-config .pc files ==="
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig" "$LFS/usr/share/pkgconfig"
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
cp -f /usr/share/pkgconfig/*.pc "$LFS/usr/share/pkgconfig/" 2>/dev/null
mkdir -p "$LFS/usr/share/aclocal"
cp -f /usr/share/aclocal/pkg.m4 "$LFS/usr/share/aclocal/" 2>/dev/null

echo "=== Step 6: Restore GCC support files ==="
cp -f /usr/bin/gcc "$LFS/usr/bin/gcc" 2>/dev/null
cp -f /usr/bin/cc "$LFS/usr/bin/cc" 2>/dev/null
cp -f /usr/bin/as "$LFS/usr/bin/as" 2>/dev/null
cp -f /usr/bin/ld "$LFS/usr/bin/ld" 2>/dev/null
for f in cc1 collect2 libgcc_s.so.1 libgcc.a crtbeginS.o crtendS.o crtbeginT.o crtbegin.o crtend.o lto-wrapper lto1 liblto_plugin.so liblto_plugin.so.0; do
    src=$(find /usr/lib/gcc/x86_64-linux-gnu/11 -name "$f" 2>/dev/null | head -1)
    [ -n "$src" ] && cp -f "$src" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
done
cp -f /usr/bin/ld "$LFS/usr/bin/ld" 2>/dev/null
cp -f /usr/bin/as "$LFS/usr/bin/as" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libopcodes* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libbfd* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null

cp -f /bin/bash "$LFS/usr/bin/bash" 2>/dev/null
rm -f "$LFS/bin/echo"; ln -sf /usr/bin/echo "$LFS/bin/echo"
rm -f "$LFS/bin/mktemp"; ln -sf /usr/bin/mktemp "$LFS/bin/mktemp"

echo "=== Step 7: Mount and verify ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /usr/bin/gcc --version 2>&1 | head -1
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /bin/echo "echo works"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /usr/bin/pkg-config --list-all 2>&1 | grep -E "libbsd|ncurses" | head -5

echo "=== Step 8: Run final build ==="
cp /mnt/e/projects/haramchy/build-final-system.sh "$LFS/home/lfs/build-final-system.sh"
chmod +x "$LFS/home/lfs/build-final-system.sh"
rm -f "$LFS/home/lfs/.build-markers/final/"*
rm -f "$LFS/var/log/haramchy-final.log"
mkdir -p "$LFS/var/log" "$LFS/tmp/build"

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash /home/lfs/build-final-system.sh 2>&1

for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
