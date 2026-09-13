#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copying libcrypt ==="
for f in libcrypt.so libcrypt.so.1 libcrypt.so.1.1.0 libcrypt.a libcrypt.pcl; do
    src=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$f" 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
        cp -f "$src" "$LFS/lib64/" 2>/dev/null
        echo "  $f"
    fi
done

# Also copy localedef (needed for locale)
cp -f /usr/bin/localedef "$LFS/usr/bin/localedef" 2>/dev/null

# Copy ALL of /usr/lib/x86_64-linux-gnu/ to ensure nothing is missing
echo "=== Bulk copying host libs ==="
cp -f /lib/x86_64-linux-gnu/libcrypt* "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libcrypt* "$LFS/lib64/" 2>/dev/null

# Fix all dangling symlinks again
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then
            rm -f "$link"
            cp -f "$real" "$link" 2>/dev/null
        fi
    fi
done
echo "=== Done ==="
'
