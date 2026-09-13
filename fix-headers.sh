#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Replace ALL glibc headers with host (2.35) consistently ==="

# Backup and replace entire usr/include with host headers
rm -rf "$LFS/usr/include.bak"
mv "$LFS/usr/include" "$LFS/usr/include.bak" 2>/dev/null
cp -r /usr/include "$LFS/usr/include"

# Copy architecture-specific headers
rm -rf "$LFS/usr/include.bak/x86_64-linux-gnu" 2>/dev/null

echo "=== Re-copy non-glibc headers from backup ==="
# Restore non-glibc headers that were built by LFS packages
for dir in linux asm asm-generic asm-x86; do
    if [ -d "$LFS/usr/include.bak/$dir" ]; then
        cp -r "$LFS/usr/include.bak/$dir" "$LFS/usr/include/" 2>/dev/null
    fi
done

# Restore LFS-built package headers (not glibc)
for h in $(find "$LFS/usr/include.bak" -maxdepth 1 -name "*.h" -newer "$LFS/usr/include.bak/limits.h" 2>/dev/null); do
    bn=$(basename "$h")
    # Skip glibc headers
    case "$bn" in stdio.h|stdlib.h|string.h|unistd.h|errno.h|fcntl.h|dirent.h|signal.h|pthread.h|time.h|wchar.h|stdint.h|features.h|assert.h|limits.h|math.h|locale.h|setjmp.h|float.h|dlfcn.h|netdb.h|resolv.h|syslog.h|argp.h|glob.h) continue;; esac
    cp -f "$h" "$LFS/usr/include/" 2>/dev/null
done

# Restore bsd headers for libbsd
mkdir -p "$LFS/usr/include/bsd"
cp -r /usr/include/bsd/* "$LFS/usr/include/bsd/" 2>/dev/null

# Restore pkg-config and pkg.m4
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig" "$LFS/usr/share/aclocal"
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
cp -f /usr/share/pkgconfig/*.pc "$LFS/usr/share/pkgconfig/" 2>/dev/null
cp -f /usr/share/aclocal/pkg.m4 "$LFS/usr/share/aclocal/" 2>/dev/null

# Restore essential binaries
cp -f /usr/bin/gawk "$LFS/usr/bin/gawk" 2>/dev/null
cp -f /usr/bin/gawk "$LFS/usr/bin/awk" 2>/dev/null
cp -f /usr/bin/gawk "$LFS/usr/bin/mawk" 2>/dev/null
cp -f /usr/bin/gawk "$LFS/usr/bin/nawk" 2>/dev/null
cp -f /usr/bin/cmp "$LFS/usr/bin/cmp" 2>/dev/null
cp -f /usr/bin/pkg-config "$LFS/usr/bin/pkg-config" 2>/dev/null
cp -f /usr/bin/echo "$LFS/usr/bin/echo" 2>/dev/null
cp -f /usr/bin/mktemp "$LFS/usr/bin/mktemp" 2>/dev/null
cp -f /usr/bin/file "$LFS/usr/bin/file" 2>/dev/null
cp -f /usr/bin/which "$LFS/usr/bin/which" 2>/dev/null
cp -f /usr/bin/find "$LFS/usr/bin/find" 2>/dev/null
cp -f /usr/bin/xargs "$LFS/usr/bin/xargs" 2>/dev/null

# Restore host shared libs
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
for src in /lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib64/$bn" 2>/dev/null
done
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null

# Restore GCC support files
cp -f /usr/bin/gcc "$LFS/usr/bin/gcc" 2>/dev/null
cp -f /usr/bin/cc "$LFS/usr/bin/cc" 2>/dev/null

# Copy cc1 and other GCC internals if not already there
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/cc1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/collect2 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so.1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc.a "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/crtbeginS.o "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/crtendS.o "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/crtbeginT.o "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/crtbegin.o "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/crtend.o "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null

# Fix dangling symlinks
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then rm -f "$link"; cp -f "$real" "$link" 2>/dev/null; fi
    fi
done

echo "=== Cleanup old include ==="
rm -rf "$LFS/usr/include.bak" 2>/dev/null

echo "=== Verify header consistency ==="
grep -c ip_mreqn "$LFS/usr/include/netinet/in.h" 2>/dev/null
'
