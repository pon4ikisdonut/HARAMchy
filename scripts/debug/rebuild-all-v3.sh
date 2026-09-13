#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Mount ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

echo "=== Check xcb_ewmh.h ==="
find "$LFS/usr/include" -name "xcb_ewmh.h" 2>/dev/null
find /usr/include" -name "xcb_ewmh.h" 2>/dev/null
ls /usr/include/xcb/xcb_ewmh.h 2>/dev/null

echo "=== Force copy xcb headers ==="
mkdir -p "$LFS/usr/include/xcb"
cp -f /usr/include/xcb/*.h "$LFS/usr/include/xcb/" 2>/dev/null
ls "$LFS/usr/include/xcb/xcb_ewmh.h" 2>/dev/null

echo "=== Create wlroots soname symlink ==="
ln -sf libwlroots.so.12 "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots.so.12032" 2>/dev/null
ln -sf libwlroots.so.12 "$LFS/usr/lib64/libwlroots.so.12032" 2>/dev/null
ln -sf libwlroots.so.12 "$LFS/usr/lib/x86_64-linux-gnu/libwlroots.so.12032" 2>/dev/null
ls -la "$LFS/tmp/build/Hyprland-0.30.0/subprojects/wlroots/build/libwlroots"* 2>/dev/null

echo "=== Build xkbcommon ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash -c "
cd /tmp
rm -rf libxkbcommon-xkbcommon-1.5.0
tar xf /sources/xkbcommon-1.5.0.tar.gz
cd libxkbcommon-xkbcommon-1.5.0
meson setup build --prefix=/usr -Denable-docs=false -Denable-wayland=false -Denable-x11=false -Denable-tools=false 2>&1 | tail -5
ninja -C build -j\$(nproc) 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3
echo XKBCOMMON_DONE
" 2>&1 | tail -15

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
echo MESA_DONE
" 2>&1 | tail -20

echo "=== Rebuild Hyprland ==="
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

echo "=== Unmount ==="
for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
