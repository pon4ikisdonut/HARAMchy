#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
BUILD=/tmp/build

echo "=== Ensure /tmp/build exists ==="
mkdir -p "$LFS/tmp/build"

echo "=== Build wlroots subproject via meson ==="
# The Hyprland subproject wlroots is a different version that includes cursor_shape
cd "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots"
rm -rf build
meson setup build --prefix=/usr -Dexamples=false -Dxwayland=disabled -Dtests=false 2>&1 | tail -5
ninja -C build 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3

echo "=== Check cursor_shape header now ==="
ls /usr/include/wlr/types/wlr_cursor_shape_v1.h 2>/dev/null

echo "=== Copy wlroots lib to x86_64-linux-gnu ==="
cp -f /usr/lib64/libwlroots.so.11* /usr/lib/x86_64-linux-gnu/ 2>/dev/null
cp -f /usr/lib64/libwlroots.so* /usr/lib/x86_64-linux-gnu/ 2>/dev/null

echo "=== Run Hyprland build ==="
cd "$LFS/tmp/build/Hyprland-0.30.0"
rm -rf build
mkdir -p build
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DLEGACY_RENDERER=ON \
    -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules \
    -DCMAKE_CXX_FLAGS="-std=gnu++20" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ 2>&1 | tail -20

cmake --build build -j$(nproc) 2>&1 | tail -20
'
