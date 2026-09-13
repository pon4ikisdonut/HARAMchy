#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy full GCC 13 include tree ==="
# Remove old GCC 11 includes, replace with GCC 13
rm -rf "$LFS/usr/include/c++/11"
rm -rf "$LFS/usr/include/c++/13"
cp -r /usr/include/c++/13 "$LFS/usr/include/c++/13"

# Copy x86_64-linux-gnu bits
rm -rf "$LFS/usr/include/x86_64-linux-gnu/c++"
mkdir -p "$LFS/usr/include/x86_64-linux-gnu/c++"
cp -r /usr/include/x86_64-linux-gnu/c++/13 "$LFS/usr/include/x86_64-linux-gnu/c++/13"

echo "=== Verify ==="
ls "$LFS/usr/include/x86_64-linux-gnu/c++/13/bits/c++config.h" 2>/dev/null
ls "$LFS/usr/include/c++/13/bits/memoryfwd.h" 2>/dev/null

echo "=== Test compile ==="
echo "int main(){}" > /tmp/test13.cpp
cp /tmp/test13.cpp "$LFS/tmp/test13.cpp"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin g++ -c /tmp/test13.cpp -o /tmp/test13.o 2>&1
echo "  Exit: $?"

echo "=== Build Hyprland ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash <<CHROOTEOF
cd /tmp/build/Hyprland-0.30.0
rm -rf build && mkdir -p build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DLEGACY_RENDERER=ON -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules -DCMAKE_C_COMPILER=/usr/bin/gcc-13 -DCMAKE_CXX_COMPILER=/usr/bin/g++-13 2>&1 | tail -5
cmake --build build -j$(nproc) 2>&1 | tail -30
CHROOTEOF
'
