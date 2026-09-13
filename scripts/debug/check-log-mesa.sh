#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
LOG="$LFS/var/log/haramchy-wayland.log"

echo "=== Lines 800-1200 of wayland log (mesa section) ==="
sed -n "800,1200p" "$LOG" 2>/dev/null
'
