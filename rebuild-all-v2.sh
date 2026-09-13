#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Build xkbcommon ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash -c "
cd /tmp
rm -rf libxkbcommon-xkbcommon-1.5.0
tar xf /sources/xkbcommon-1.5.0.tar.gz
cd libxkbcommon-xkbcommon-1.5.0
meson setup build --prefix=/usr -Denable-docs=false -Denable-wayland=false -Denable-x11=false -Denable-tools=false 2>&1 | tail -5
ninja -C build -j\$(nproc) 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3
" 2>&1 | tail -15

echo ""
echo "=== Build mesa ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash -c "
cd /tmp
rm -rf mesa-23.2.1
tar xf /sources/mesa-23.2.1.tar.xz
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
ninja -C build -j\$(nproc) 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3
" 2>&1 | tail -20

echo ""
echo "=== Build Hyprland ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash -c "
cd /tmp/build/Hyprland-0.30.0
rm -rf build
mkdir -p build
cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DLEGACY_RENDERER=ON \
    -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules \
    -DCMAKE_CXX_FLAGS=\"-std=gnu++20\" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ 2>&1 | tail -10
cmake --build build -j\$(nproc) 2>&1 | tail -20
" 2>&1 | tail -30
'
