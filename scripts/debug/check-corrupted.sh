#!/bin/bash
cd /home/lfs/src
for f in *.tar.*; do
    if file "$f" 2>/dev/null | grep -qE 'HTML|ASCII text'; then
        echo "CORRUPTED: $f"
    fi
done
echo "=== done ==="
