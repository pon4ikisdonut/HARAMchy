#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy GCC 13 to chroot ==="
cp -f /usr/bin/gcc-13 "$LFS/usr/bin/gcc-13" 2>/dev/null
cp -f /usr/bin/g++-13 "$LFS/usr/bin/g++-13" 2>/dev/null
cp -f /usr/bin/gcc "$LFS/usr/bin/gcc" 2>/dev/null
cp -f /usr/bin/g++ "$LFS/usr/bin/g++" 2>/dev/null
cp -f /usr/bin/cc "$LFS/usr/bin/cc" 2>/dev/null
# Copy GCC 13 libraries and includes
cp -r /usr/lib/gcc/x86_64-linux-gnu/13 "$LFS/usr/lib/gcc/x86_64-linux-gnu/" 2>/dev/null
# Copy libstdc++ from GCC 13
cp -f /usr/lib/x86_64-linux-gnu/libstdc++.so.6 "$LFS/usr/lib/x86_64-linux-gnu/libstdc++.so.6" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libstdc++.so.6* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
# Copy libgcc_s
cp -f /lib/x86_64-linux-gnu/libgcc_s.so.1 "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null

echo "=== Copy wayland-egl-backend.pc ==="
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/wayland-egl-backend.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/wayland-egl-backend.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
find /usr -name "wayland-egl-backend.pc" 2>/dev/null

echo "=== Copy m4 ==="
cp -f /usr/bin/m4 "$LFS/usr/bin/m4" 2>/dev/null

echo "=== Verify gcc ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin g++-13 --version 2>&1 | head -1
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin g++ --version 2>&1 | head -1

echo "=== Build Hyprland with GCC 13 ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash <<CHROOTEOF
cd /tmp/build/Hyprland-0.30.0
rm -rf build && mkdir -p build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DLEGACY_RENDERER=ON -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules -DCMAKE_C_COMPILER=/usr/bin/gcc-13 -DCMAKE_CXX_COMPILER=/usr/bin/g++-13 2>&1 | tail -10
cmake --build build -j$(nproc) 2>&1 | tail -30
CHROOTEOF
'
