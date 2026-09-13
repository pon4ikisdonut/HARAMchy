#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
LOG="$LFS/var/log/haramchy-wayland.log"

echo "=== Check if wlroots installed headers ==="
find "$LFS/usr/include" -path "*/wlr/*" -type f 2>/dev/null | head -10

echo ""
echo "=== Check wlroots library ==="
ls -la "$LFS/usr/lib/x86_64-linux-gnu/libwlroots"* 2>/dev/null
ls -la "$LFS/usr/lib64/libwlroots"* 2>/dev/null

echo ""
echo "=== Recent mesa errors (last 200 lines) ==="
tail -200 "$LOG" | grep -B2 -A5 "mako\|ERROR" | head -30

echo ""
echo "=== Check xkbcommon bison error ==="
tail -200 "$LOG" | grep -B2 -A5 "bison\|m4sugar" | head -20

echo ""
echo "=== Check python mako ==="
python3 -c "import mako; print(mako.__version__)" 2>&1

echo ""
echo "=== Check Hyprland build errors (last 30 lines) ==="
tail -30 "$LOG" | grep -i "error\|fatal"
'
