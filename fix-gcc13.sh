#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Fix gcc symlinks ==="
ln -sf gcc-13 "$LFS/usr/bin/gcc"
ln -sf g++-13 "$LFS/usr/bin/g++"
ln -sf gcc-13 "$LFS/usr/bin/cc"

echo "=== Copy cc1plus for gcc-13 ==="
mkdir -p "$LFS/usr/lib/gcc/x86_64-linux-gnu/13"
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/cc1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/cc1plus "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/collect2 "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/lto-wrapper "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/lto1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/liblto_plugin.so "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/libgcc.a "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/libgcc_s.so.1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/libstdc++.a "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/libstdc++.so "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/libstdc++.so.6 "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
for f in crtbeginS.o crtendS.o crtbeginT.o crtbegin.o crtend.o; do
    cp -f /usr/lib/gcc/x86_64-linux-gnu/13/$f "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null
done
cp -f /usr/lib/gcc/x86_64-linux-gnu/13/libgcc_s.so "$LFS/usr/lib/gcc/x86_64-linux-gnu/13/" 2>/dev/null

echo "=== Verify ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin g++ --version 2>&1 | head -1
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin gcc --version 2>&1 | head -1

echo "=== Test g++ -c ==="
echo "int main(){}" > /tmp/test13.cpp
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin g++ -c /tmp/test13.cpp -o /tmp/test13.o 2>&1
'
