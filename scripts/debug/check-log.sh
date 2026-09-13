#!/bin/bash
echo 177695 | sudo -S bash -c '
LOG=/home/lfs/lfs-root/var/log/haramchy-wayland.log

echo "=== MESA ERRORS ==="
grep -A 5 "ERROR" "$LOG" | grep -i "mesa" -A 5 | tail -30

echo ""
echo "=== XKBCOMMON ERRORS ==="
grep -B2 -A 5 "error:" "$LOG" | grep -B2 -A 5 "xkb" | tail -30

echo ""
echo "=== WLROOTS ERRORS ==="
grep -B2 -A 5 "error:" "$LOG" | grep -B2 -A 5 "wlroots" | tail -30

echo ""
echo "=== HYPRLAND ERRORS ==="
grep -B2 -A 5 "error:" "$LOG" | grep -B2 -A 5 -i "hypr" | tail -30

echo ""
echo "=== ALL ERRORS ==="
grep -n "error:" "$LOG" | tail -40
'
