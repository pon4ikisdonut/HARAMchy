#!/bin/bash
for f in $(find /home/lfs/lfs-root -name 'libdrm*' -type f 2>/dev/null); do
    if nm -D "$f" 2>/dev/null | grep -q dumb; then
        echo "FOUND: $f"
        nm -D "$f" | grep dumb
    fi
done
echo "Done scanning"
