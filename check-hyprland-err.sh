#!/bin/bash
echo 177695 | sudo -S bash -c '
LOG=/home/lfs/lfs-root/var/log/haramchy-wayland.log
echo "=== Hyprland build errors ==="
awk "/Hyprland/,/Build Complete/" "$LOG" | grep -i "error\|fatal\|fail" | head -30

echo ""
echo "=== Mesa error detail ==="
awk "/mesa/,/mesa-done/" "$LOG" | grep -i "error\|not found\|NOT\|unknown" | head -10

echo ""
echo "=== xkbcommon error detail ==="
awk "/xkbcommon-done/,/xkbcommon-done/" "$LOG" | grep -i "error\|fail" | head -10
'
