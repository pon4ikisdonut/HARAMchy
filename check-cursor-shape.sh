#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Check wlroots installed types headers ==="
ls "$LFS/usr/include/wlr/types/" 2>/dev/null | sort

echo ""
echo "=== Is cursor_shape in wlroots source? ==="
find /tmp/build/wlroots-0.16.2 -name "wlr_cursor_shape*" 2>/dev/null

echo ""
echo "=== Check Hyprland source for cursor_shape ==="
grep -r "cursor_shape" /tmp/build/Hyprland-0.30.0/src/ 2>/dev/null | head -5

echo ""
echo "=== Copy mako to chroot python3 dist-packages ==="
mkdir -p "$LFS/usr/lib/python3/dist-packages"
cp -r /usr/lib/python3/dist-packages/mako "$LFS/usr/lib/python3/dist-packages/" 2>/dev/null
cp -r /usr/lib/python3/dist-packages/MarkupSafe "$LFS/usr/lib/python3/dist-packages/" 2>/dev/null
python3 -c "import mako; print(mako.__version__)"
'
