#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Check wlr_cursor_shape header ==="
find "$LFS/usr/include/wlr" -name "*cursor_shape*" 2>/dev/null
find "$LFS/usr/include/wlr/types" -name "*.h" 2>/dev/null | head -20

echo ""
echo "=== Check wlroots lib path ==="
ls -la "$LFS/usr/lib64/libwlroots"* 2>/dev/null
ls -la "$LFS/usr/lib/x86_64-linux-gnu/libwlroots"* 2>/dev/null

echo ""
echo "=== Install python3-mako ==="
apt-get install -y python3-mako 2>&1 | tail -3

echo ""
echo "=== Install mako in chroot ==="
python3 -m pip install mako 2>&1 | tail -3
# Or copy from host
cp -r /usr/lib/python3/dist-packages/mako "$LFS/usr/lib/python3.10/" 2>/dev/null
cp -r /usr/lib/python3/dist-packages/mako "$LFS/usr/lib/python3/dist-packages/" 2>/dev/null

echo ""
echo "=== Copy wlroots lib to x86_64-linux-gnu ==="
cp -f "$LFS/usr/lib64/libwlroots.so.11" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f "$LFS/usr/lib64/libwlroots.so" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
ln -sf libwlroots.so.11 "$LFS/usr/lib/x86_64-linux-gnu/libwlroots.so"

echo ""
echo "=== Check cursor_shape_v1 protocol from wayland-protocols ==="
find "$LFS/usr/share/wayland-protocols" -name "*cursor-shape*" 2>/dev/null
'
