#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copy libexec gcc-13 ==="
mkdir -p "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13"
cp -f /usr/libexec/gcc/x86_64-linux-gnu/13/cc1plus "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13/"
cp -f /usr/libexec/gcc/x86_64-linux-gnu/13/cc1 "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13/"
cp -f /usr/libexec/gcc/x86_64-linux-gnu/13/collect2 "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13/"
cp -f /usr/libexec/gcc/x86_64-linux-gnu/13/lto-wrapper "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13/"
cp -f /usr/libexec/gcc/x86_64-linux-gnu/13/lto1 "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13/"
cp -f /usr/libexec/gcc/x86_64-linux-gnu/13/liblto_plugin.so "$LFS/usr/libexec/gcc/x86_64-linux-gnu/13/" 2>/dev/null

echo "=== Test g++ ==="
echo "int main(){}" > /tmp/test13.cpp
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin g++ -c /tmp/test13.cpp -o /tmp/test13.o 2>&1
echo "  Exit: $?"

echo "=== Also copy libstdc++ headers ==="
cp -r /usr/include/c++/13 "$LFS/usr/include/c++/" 2>/dev/null

echo "=== Build Hyprland ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin bash <<CHROOTEOF
cd /tmp/build/Hyprland-0.30.0
rm -rf build && mkdir -p build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DLEGACY_RENDERER=ON -DCMAKE_MODULE_PATH=/usr/share/cmake/Modules -DCMAKE_C_COMPILER=/usr/bin/gcc-13 -DCMAKE_CXX_COMPILER=/usr/bin/g++-13 2>&1 | tail -10
cmake --build build -j$(nproc) 2>&1 | tail -30
CHROOTEOF
'
