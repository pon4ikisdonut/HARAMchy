#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy ALL dev headers from host ==="
# Copy all of /usr/include (replacing the chroot one)
rm -rf "$LFS/usr/include"
cp -r /usr/include "$LFS/usr/include"
echo "  Headers copied"

echo "=== Copy ALL .pc files ==="
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig" "$LFS/usr/share/pkgconfig"
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
cp -f /usr/share/pkgconfig/*.pc "$LFS/usr/share/pkgconfig/" 2>/dev/null
echo "  pkg-config files: $(ls "$LFS/usr/lib/pkgconfig/"*.pc 2>/dev/null | wc -l)"

echo "=== Copy ALL shared libs ==="
for src in /lib/x86_64-linux-gnu/*.so* /usr/lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
done
echo "  shared libs"

echo "=== Copy wayland-scanner ==="
cp -f /usr/bin/wayland-scanner "$LFS/usr/bin/wayland-scanner" 2>/dev/null
cp -f /usr/bin/wayland-scanner++ "$LFS/usr/bin/wayland-scanner++" 2>/dev/null
cp -f /usr/bin/git "$LFS/usr/bin/git" 2>/dev/null
cp -f /usr/bin/git "$LFS/usr/bin/git" 2>/dev/null
# Copy wayland-scanner++ if it exists
find /usr/bin -name "wayland-scanner*" 2>/dev/null | while read f; do
    cp -f "$f" "$LFS/usr/bin/" 2>/dev/null
done

echo "=== Fix dangling symlinks ==="
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then rm -f "$link"; cp -f "$real" "$link" 2>/dev/null; fi
    fi
done

echo "=== Copy ESSENTIAL binaries ==="
for tool in echo mktemp cat ls chmod chown date dd head install ln mkdir rm rmdir tail touch env nproc seq test truncate wc basename comm cut dirname expand fmt fold id join logname od paste printenv readlink realpath shuf sort tac tee tr tsort uniq unlink which find xargs diff file gawk awk cmp pkg-config ld as ar objcopy objdump ranlib nm strip readelf cmake ninja meson python3 g++ git wayland-scanner; do
    src=$(which "$tool" 2>/dev/null)
    if [ -n "$src" ] && [ -f "$src" ]; then
        cp -f "$src" "$LFS/usr/bin/$tool" 2>/dev/null
    fi
done

rm -f "$LFS/bin/echo"; ln -sf /usr/bin/echo "$LFS/bin/echo"
rm -f "$LFS/bin/mktemp"; ln -sf /usr/bin/mktemp "$LFS/bin/mktemp"
cp -f /bin/bash "$LFS/usr/bin/bash" 2>/dev/null

# Restore gcc, g++
cp -f /usr/bin/gcc "$LFS/usr/bin/gcc" 2>/dev/null
cp -f /usr/bin/cc "$LFS/usr/bin/cc" 2>/dev/null
cp -f /usr/bin/g++ "$LFS/usr/bin/g++" 2>/dev/null
cp -f /usr/bin/g++-11 "$LFS/usr/bin/g++-11" 2>/dev/null
for f in cc1 cc1plus collect2 libgcc_s.so.1 libgcc.a crtbeginS.o crtendS.o crtbeginT.o crtbegin.o crtend.o lto-wrapper lto1 liblto_plugin.so; do
    src=$(find /usr/lib/gcc/x86_64-linux-gnu/11 -name "$f" 2>/dev/null | head -1)
    [ -n "$src" ] && cp -f "$src" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
done

echo "=== Verify ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /usr/bin/pkg-config --list-all 2>&1 | grep -cE "cairo|pango|pixman|wayland" || true
echo "pkg-config packages found"
'
