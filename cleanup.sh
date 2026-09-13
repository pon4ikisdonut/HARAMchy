#!/bin/bash
echo 177695 | sudo -S bash -c '
echo "=== Removing old build markers ==="
rm -rf /home/lfs/.build-markers/tmp-tools/*

echo "=== Removing empty/broken tarballs ==="
cd /home/lfs/src
for f in *.tar.*; do
    if [ ! -s "$f" ]; then
        echo "  REMOVED: $f (empty)"
        rm -f "$f"
    elif ! file "$f" | grep -qi "compress"; then
        # Check if its a known non-archive
        case "$f" in
            *HTML*) echo "  REMOVED: $f (HTML)"; rm -f "$f" ;;
            *check*0.15*) echo "  REMOVED: $f (missing package)"; rm -f "$f" ;;
        esac
    fi
done

echo "=== Cleaning build dirs ==="
rm -rf /tmp/build
rm -rf /home/lfs/build/groff-1.23.0 /home/lfs/build/man-db-2.12.0

echo "=== Done ==="
'
