#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy python3-mako to chroot ==="
cp -r /usr/lib/python3/dist-packages/mako "$LFS/usr/lib/python3.10/" 2>/dev/null
cp -r /usr/lib/python3/dist-packages/MarkupSafe "$LFS/usr/lib/python3.10/" 2>/dev/null
mkdir -p "$LFS/usr/lib/python3/dist-packages"
cp -r /usr/lib/python3/dist-packages/mako "$LFS/usr/lib/python3/dist-packages/" 2>/dev/null
cp -r /usr/lib/python3/dist-packages/MarkupSafe "$LFS/usr/lib/python3/dist-packages/" 2>/dev/null

echo "=== Fix xkbcommon: bison data already copied ==="
ls "$LFS/usr/share/bison/m4sugar/m4sugar.m4" 2>/dev/null

echo "=== Clear failed markers ==="
rm -f "$LFS/home/lfs/.build-markers/wayland/mesa-done"
rm -f "$LFS/home/lfs/.build-markers/wayland/xkbcommon-done"
rm -f "$LFS/home/lfs/.build-markers/wayland/hyprland-done"

echo "=== Rebuild xkbcommon ==="
rm -rf "$LFS/tmp/build/libxkbcommon-xkbcommon-1.5.0"
cp /mnt/e/projects/haramchy/build-wayland-stack.sh "$LFS/home/lfs/build-wayland-stack.sh"
chmod +x "$LFS/home/lfs/build-wayland-stack.sh"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash -c "
cd /tmp/build
tar xf /sources/xkbcommon-1.5.0.tar.gz 2>/dev/null
cd libxkbcommon-xkbcommon-1.5.0
meson setup build --prefix=/usr -Denable-docs=false -Denable-wayland=false -Denable-x11=false -Denable-tools=false 2>&1 | tail -5
ninja -C build -j$(nproc) 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3
" 2>&1

echo "=== Rebuild mesa ==="
rm -rf "$LFS/tmp/build/mesa-23.2.1"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash -c "
cd /tmp/build
tar xf /sources/mesa-23.2.1.tar.xz 2>/dev/null
cd mesa-23.2.1
meson setup build --prefix=/usr \
    -Dgallium-drivers=swrast \
    -Dvulkan-drivers=\"\" \
    -Dglvnd=false \
    -Dplatforms=x11,wayland \
    -Ddri3=false \
    -Dgallium-va=false \
    -Dgallium-vdpau=false \
    -Dllvm=false \
    -Dshared-llvm=false \
    -Dvalgrind=false \
    -Dlibunwind=false 2>&1 | tail -10
ninja -C build -j$(nproc) 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3
" 2>&1

echo "=== Rebuild Hyprland ==="
cd "$LFS/tmp/build/Hyprland-0.30.0"
rm -rf build
mkdir -p build
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    cmake -B /tmp/build/Hyprland-0.30.0/build -S /tmp/build/Hyprland-0.30.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLEGACY_RENDERER=ON \
    -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules \
    -DCMAKE_CXX_FLAGS=\"-std=gnu++20\" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ 2>&1 | tail -10

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    cmake --build /tmp/build/Hyprland-0.30.0/build -j$(nproc) 2>&1 | tail -15
'
