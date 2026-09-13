#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Recursive lib copy ==="

# Copy ALL libs needed by cc1 (the real compiler)
while true; do
    missing=""
    for bin in "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/cc1" "$LFS/usr/bin/gcc" "$LFS/usr/bin/as" "$LFS/usr/bin/ld"; do
        [ -f "$bin" ] || continue
        for lib in $(ldd "$bin" 2>/dev/null | grep -oP "=> \K[^ ]+" || true); do
            basename_lib=$(basename "$lib")
            # Check if it exists in our lib paths
            found=0
            for path in "$LFS/lib64" "$LFS/lib/x86_64-linux-gnu" "$LFS/usr/lib/x86_64-linux-gnu"; do
                [ -f "$path/$basename_lib" ] && found=1 && break
            done
            if [ $found -eq 0 ]; then
                missing="$missing $basename_lib"
            fi
        done
    done
    
    if [ -z "$missing" ]; then
        echo "All libs present!"
        break
    fi
    
    echo "Missing: $missing"
    for lib in $missing; do
        src=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$lib" 2>/dev/null | head -1)
        if [ -n "$src" ]; then
            cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
            cp -f "$src" "$LFS/lib64/" 2>/dev/null
            echo "  Copied: $lib"
        else
            echo "  NOT FOUND on host: $lib"
        fi
    done
done

echo "=== Verify ==="
ldd "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/cc1" 2>/dev/null | grep "not found" || echo "cc1: all libs OK"
ldd "$LFS/usr/bin/gcc" 2>/dev/null | grep "not found" || echo "gcc: all libs OK"
ldd "$LFS/usr/bin/as" 2>/dev/null | grep "not found" || echo "as: all libs OK"
ldd "$LFS/usr/bin/ld" 2>/dev/null | grep "not found" || echo "ld: all libs OK"
'
