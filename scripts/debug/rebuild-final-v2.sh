#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy ALL xcb headers ==="
mkdir -p "$LFS/usr/include/xcb"
cp -rf /usr/include/xcb/*.h "$LFS/usr/include/xcb/"
echo "  Count: $(ls "$LFS/usr/include/xcb/" | wc -l)"

echo "=== Copy flex ==="
cp -f /usr/bin/flex "$LFS/usr/bin/flex" 2>/dev/null

echo "=== Fix bison m4 path ==="
# The issue is bison cant find m4sugar - check paths
ls "$LFS/usr/share/bison/m4sugar/m4sugar.m4" 2>/dev/null
# Try setting BISON_PKGDATADIR
export BISON_PKGDATADIR=/usr/share/bison

echo "=== Copy all xcb libs ==="
for f in /usr/lib/x86_64-linux-gnu/libxcb*.so*; do
    cp -f "$f" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
done
for f in /usr/lib/x86_64-linux-gnu/pkgconfig/xcb*.pc; do
    cp -f "$f" "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
    cp -f "$f" "$LFS/usr/lib/pkgconfig/" 2>/dev/null
done

echo "=== Build udis86 ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash <<CHROOTEOF
cd /tmp/build/Hyprland-0.30.0/subprojects/udis86
ls CMakeLists.txt
mkdir -p build
cmake -B build -S . -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_POSITION_INDEPENDENT_CODE=ON 2>&1 | tail -5
cmake --build build -j$(nproc) 2>&1 | tail -5
ls build/libudis86/liblibudis86.a 2>/dev/null
echo UDIS86_DONE
CHROOTEOF

echo "=== Rebuild xkbcommon ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin BISON_PKGDATADIR=/usr/share/bison bash <<CHROOTEOF
cd /tmp && rm -rf libxkbcommon-xkbcommon-1.5.0
tar xf /sources/xkbcommon-1.5.0.tar.gz
cd libxkbcommon-xkbcommon-1.5.0
meson setup build --prefix=/usr -Denable-docs=false -Denable-wayland=false -Denable-x11=false -Denable-tools=false 2>&1 | tail -5
BISON_PKGDATADIR=/usr/share/bison ninja -C build -j$(nproc) 2>&1 | tail -5
BISON_PKGDATADIR=/usr/share/bison ninja -C build install 2>&1 | tail -3
echo XKBCOMMON_DONE
CHROOTEOF
umount "$LFS/sources" 2>/dev/null

echo "=== Rebuild mesa ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash <<CHROOTEOF
cd /tmp && rm -rf mesa-23.2.1
tar xf /sources/mesa-23.2.1.tar.xz
cd mesa-23.2.1
meson setup build --prefix=/usr -Dgallium-drivers=swrast -Dvulkan-drivers="" -Dglvnd=false -Dplatforms=x11,wayland -Ddri3=false -Dgallium-va=false -Dgallium-vdpau=false -Dllvm=false -Dshared-llvm=false -Dvalgrind=false -Dlibunwind=false 2>&1 | tail -10
ninja -C build -j$(nproc) 2>&1 | tail -5
ninja -C build install 2>&1 | tail -3
echo MESA_DONE
CHROOTEOF
umount "$LFS/sources" 2>/dev/null

echo "=== Rebuild Hyprland ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash <<CHROOTEOF
cd /tmp/build/Hyprland-0.30.0
rm -rf build && mkdir -p build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DLEGACY_RENDERER=ON -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules "-DCMAKE_CXX_FLAGS=-std=gnu++20" -DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++ 2>&1 | tail -10
cmake --build build -j$(nproc) 2>&1 | tail -20
CHROOTEOF
'
