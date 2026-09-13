#!/bin/bash
echo 177695 | sudo -S bash -c '
HL=/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0

echo "=== Get correct wlroots version ==="
# libwlroots.so.12032 = wlroots 0.17.x
# Check what the GitHub API says about the submodule commit
curl -sL "https://api.github.com/repos/hyprwm/Hyprland/git/trees/v0.30.0?recursive=1" 2>/dev/null | grep -o "\"sha\":\"[a-f0-9]*\",\"path\":\"subprojects/wlroots\"" | head -1

echo ""
echo "=== Try wlroots 0.17.1 ==="
rm -rf "$HL/subprojects/wlroots"
git clone --depth=1 --branch 0.17.1 https://gitlab.freedesktop.org/wlroots/wlroots.git "$HL/subprojects/wlroots" 2>&1 | tail -3
chmod -R a+w "$HL/subprojects/wlroots"

echo ""
echo "=== Check cursor_shape ==="
ls "$HL/subprojects/wlroots/include/wlr/types/wlr_cursor_shape_v1.h" 2>/dev/null

echo ""
echo "=== Check meson version requirement ==="
head -3 "$HL/subprojects/wlroots/meson.build" 2>/dev/null

echo ""
echo "=== Build wlroots 0.17.1 ==="
rm -rf "$HL/subprojects/wlroots/build"
chroot /home/lfs/lfs-root /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    bash -c "cd /tmp/build/Hyprland-0.30.0/subprojects/wlroots && meson setup build --prefix=/usr -Dexamples=false -Dxwayland=disabled 2>&1" | tail -15
'
