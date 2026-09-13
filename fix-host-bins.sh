#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copying essential host binaries ==="
# Copy coreutils binaries that the chroot needs
for tool in echo mktemp cat ls chmod chown date dd head install ln ls mkdir mknod mkfifo rm rmdir tail touch envexpr nproc numfmt Pinky seq test timeout truncate wc arch base32 basename comm csplit cut dir dircolors dirname expand fmt fold groups id join logname md5sum nice nohup od paste pathchk pr printenv ptx readlink realpath runcon sha1sum sha224sum sha256sum sha384sum sha512sum shred shuf sort split stdbuf sum tac tee tr tsort unexpand uniq unlink vdir; do
    src=$(which "$tool" 2>/dev/null)
    if [ -n "$src" ] && [ -f "$src" ]; then
        cp -f "$src" "$LFS/usr/bin/$tool" 2>/dev/null
    fi
done

# Also copy mktemp, which, find, xargs, diff, tr, sort
for tool in mktemp which find xargs diff tr sort file; do
    src=$(which "$tool" 2>/dev/null)
    if [ -n "$src" ] && [ -f "$src" ]; then
        cp -f "$src" "$LFS/usr/bin/$tool" 2>/dev/null
    fi
done

# Fix dangling symlinks
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then rm -f "$link"; cp -f "$real" "$link" 2>/dev/null; fi
    fi
done

# Restore all host shared libs
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2" 2>/dev/null
for src in /lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib64/$bn" 2>/dev/null
done
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null

# Fix symlinks for echo/mktemp (should point to real binaries)
rm -f "$LFS/bin/echo" "$LFS/bin/mktemp"
ln -sf /usr/bin/echo "$LFS/bin/echo"
ln -sf /usr/bin/mktemp "$LFS/bin/mktemp"

echo "=== Verify ==="
ls -la "$LFS/usr/bin/echo" "$LFS/usr/bin/mktemp" "$LFS/bin/echo" "$LFS/bin/mktemp" 2>&1
'
