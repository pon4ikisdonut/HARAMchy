#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copying all GCC runtime dependencies ==="

# Find and copy all shared libraries that gcc/cc1 need
for lib in libisl.so.23 libmpc.so.3 libmpfr.so.6 libgmp.so.10 libgomp.so.1 \
           libstdc++.so.6 libgcc_s.so.1 libz.so.1 libc.so.6 libm.so.6 \
           libdl.so.2 libpthread.so.0 librt.so.1 libresolv.so.2 \
           libtinfo.so.6 libselinux.so.1 libpcre2-8.so.0 \
           libnss_dns.so.2 libnss_files.so.2; do
    src=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$lib" 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
        cp -f "$src" "$LFS/lib64/" 2>/dev/null
        echo "  $lib"
    else
        echo "  MISSING: $lib"
    fi
done

# Also copy the .so symlinks for linker
for lib in libisl.so libmpc.so libmpfr.so libgmp.so libz.so; do
    src=$(find /usr/lib/x86_64-linux-gnu -name "$lib" -type f -o -name "$lib" -type l 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
        echo "  $lib (symlink)"
    fi
done

echo "=== Done ==="
'
