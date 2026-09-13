#!/bin/bash
echo 177695 | sudo -S bash -c '
echo "=== Check Hyprland includes.hpp line 107 ==="
sed -n "100,115p" /tmp/build/Hyprland-0.30.0/src/includes.hpp 2>/dev/null

echo ""
echo "=== Check wlroots subproject for cursor_shape ==="
find /tmp/build/Hyprland-0.30.0/subprojects/wlroots -name "*cursor_shape*" 2>/dev/null
find /tmp/build/Hyprland-0.30.0/subprojects/wlroots/include -name "*.h" 2>/dev/null | head -10

echo ""
echo "=== Check wlroots subproject meson for cursor_shape ==="
grep -r "cursor_shape" /tmp/build/Hyprland-0.30.0/subprojects/wlroots/ 2>/dev/null | head -10
'
