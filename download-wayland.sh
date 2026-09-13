#!/bin/bash
SRC="/home/lfs/src"
mkdir -p "$SRC"

download() {
    local url="$1" dest="$2"
    echo "  $dest..."
    curl -L --connect-timeout 30 --max-time 120 -o "$SRC/$dest" "$url" 2>&1
    if [ -s "$SRC/$dest" ]; then
        echo "  OK: $(du -h "$SRC/$dest" | cut -f1)"
    else
        echo "  FAILED"
    fi
}

echo 177695 | sudo -S bash -c "
SRC=/home/lfs/src

echo '=== Downloading Wayland stack packages ==='

download() {
    local url=\"\$1\" dest=\"\$2\"
    echo \"  \$dest...\"
    curl -L --connect-timeout 30 --max-time 300 -o \"\$SRC/\$dest\" \"\$url\" 2>&1
    if [ -s \"\$SRC/\$dest\" ]; then
        echo \"  OK: \$(du -h \"\$SRC/\$dest\" | cut -f1)\"
    else
        echo \"  FAILED: \$dest\"
    fi
}

download 'https://gitlab.freedesktop.org/wayland/wayland-protocols/-/archive/1.32/wayland-protocols-1.32.tar.gz' 'wayland-protocols-1.32.tar.gz'
download 'https://gitlab.freedesktop.org/wayland/wayland/-/archive/1.22.0/wayland-1.22.0.tar.gz' 'wayland-1.22.0.tar.gz'
download 'https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz' 'libdrm-2.4.120.tar.xz'
download 'https://www.cairographics.org/releases/pixman-0.42.2.tar.gz' 'pixman-0.42.2.tar.gz'
download 'https://mesa.freedesktop.org/archive/mesa-23.2.1.tar.xz' 'mesa-23.2.1.tar.xz'
download 'https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.5.0.tar.gz' 'xkbcommon-1.5.0.tar.gz'
download 'https://git.sr.ht/~kennylevinsen/seatd/archive/0.7.0.tar.gz' 'seatd-0.7.0.tar.gz'
download 'https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.16.2/wlroots-0.16.2.tar.gz' 'wlroots-0.16.2.tar.gz'
download 'https://github.com/hyprwm/Hyprland/archive/refs/tags/v0.30.0.tar.gz' 'Hyprland-0.30.0.tar.gz'
"
