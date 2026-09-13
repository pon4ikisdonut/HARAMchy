#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Fixing dangling symlinks and copying missing libs ==="

# Copy libpcre.so.3
cp -f /lib/x86_64-linux-gnu/libpcre.so.3 "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libpcre.so.3 "$LFS/lib64/" 2>/dev/null
echo "  libpcre.so.3"

# Find and fix ALL dangling symlinks
echo "=== Fixing dangling symlinks ==="
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    target=$(readlink "$link" 2>/dev/null)
    if [ ! -e "$link" ]; then
        # Find the real file on the host
        basename_lib=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu /usr/lib/gcc -name "$basename_lib" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then
            rm -f "$link"
            cp -f "$real" "$link" 2>/dev/null
            echo "  Fixed: $link"
        else
            echo "  Cannot fix: $link (was -> $target)"
        fi
    fi
done

echo "=== Copy ALL missing shared libs from host ==="
# For every binary in usr/bin and usr/lib/gcc, find what libs they need
# and ensure they exist in the chroot
for bindir in "$LFS/usr/bin" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11"; do
    for bin in "$bindir"/*; do
        [ -f "$bin" ] && [ -x "$bin" ] || continue
        ldd "$bin" 2>/dev/null | while read line; do
            lib_path=$(echo "$line" | grep -oP "=> \K\S+")
            lib_name=$(echo "$line" | grep -oP "^\s*\K\S+")
            [ -z "$lib_path" ] && [ -n "$lib_name" ] && lib_path="$lib_name"
            [ -z "$lib_path" ] && continue
            [ "$lib_path" = "not" ] && continue
            basename_lib=$(basename "$lib_path")
            found=0
            for p in "$LFS/lib64" "$LFS/lib/x86_64-linux-gnu" "$LFS/usr/lib/x86_64-linux-gnu" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11"; do
                [ -e "$p/$basename_lib" ] && found=1 && break
            done
            if [ $found -eq 0 ]; then
                real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$basename_lib" -not -type l 2>/dev/null | head -1)
                if [ -n "$real" ]; then
                    cp -f "$real" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
                    cp -f "$real" "$LFS/lib64/" 2>/dev/null
                    echo "  Copied: $basename_lib"
                fi
            fi
        done
    done
done

echo "=== Verify ==="
ldd "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/cc1" 2>/dev/null | grep "not found" || echo "cc1: OK"
ldd "$LFS/usr/bin/gcc" 2>/dev/null | grep "not found" || echo "gcc: OK"
ldd "$LFS/usr/bin/grep" 2>/dev/null | grep "not found" || echo "grep: OK"
ldd "$LFS/usr/bin/sed" 2>/dev/null | grep "not found" || echo "sed: OK"
ldd "$LFS/usr/bin/make" 2>/dev/null | grep "not found" || echo "make: OK"
ldd "$LFS/usr/bin/tar" 2>/dev/null | grep "not found" || echo "tar: OK"
'
