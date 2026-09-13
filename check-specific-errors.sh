#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
LOG="$LFS/var/log/haramchy-wayland.log"

echo "=== Mesa section ==="
grep -n "mesa" "$LOG" | grep -i "config\|error\|fail\|found\|not"

echo ""
echo "=== Find mesa configure error ==="
awk "/mesa-23/,/mark_done/" "$LOG" | grep -i "error\|NOT\|not found\|fail" | head -20

echo ""
echo "=== xkbcommon build section ==="
awk "/xkbcommon/,/mark_done/" "$LOG" | grep -i "error\|fail" | head -20

echo ""
echo "=== Wayland lib version check ==="
grep "Found wayland-server" "$LOG" | tail -5
'
