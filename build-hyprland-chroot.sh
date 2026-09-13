#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Build wlroots subproject inside chroot ==="
# Build the wlroots that Hyprland ships as subproject
cd "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots"
rm -rf build
# Need meson build inside chroot
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    meson setup /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build \
    /tmp/build/Hyprland-0.30.0/subprojects/wlroots \
    --prefix=/usr -Dexamples=false -Dxwayland=disabled -Dtests=false 2>&1 | tail -10

echo "=== Build wlroots ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    ninja -C /tmp/build/Hyprland-0.30.0/subprojects/wlroots/build -j$(nproc) 2>&1 | tail -10

echo "=== Check lib ==="
ls -la "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots"* 2>/dev/null

echo "=== Now build Hyprland ==="
cd "$LFS/tmp/build/Hyprland-0.30.0"
rm -rf build
mkdir -p build
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    cmake -B /tmp/build/Hyprland-0.30.0/build -S /tmp/build/Hyprland-0.30.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLEGACY_RENDERER=ON \
    -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules \
    -DCMAKE_CXX_FLAGS="-std=gnu++20" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ 2>&1 | tail -20

echo "=== Build ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    cmake --build /tmp/build/Hyprland-0.30.0/build -j$(nproc) 2>&1 | tail -30
'
