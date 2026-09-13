#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2"
cp -f /lib/x86_64-linux-gnu/libc.so.6 "$LFS/lib64/libc.so.6"
mkdir -p "$LFS/lib/x86_64-linux-gnu"
for lib in libc.so.6 libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libgmp.so.10 libgomp.so.1 libstdc++.so.6 libgcc_s.so.1 libz.so.1; do
    cp -f /lib/x86_64-linux-gnu/$lib "$LFS/lib/x86_64-linux-gnu/$lib" 2>/dev/null
    cp -f /lib/x86_64-linux-gnu/$lib "$LFS/lib64/$lib" 2>/dev/null
done

mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

echo "=== Testing GCC ==="
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/bin TERM=linux /usr/bin/gcc --version 2>&1 | head -3

echo "=== Testing compile ==="
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/bin TERM=linux /usr/bin/bash -c "echo int main\(\){return 0;} > /tmp/test.c && /usr/bin/gcc -o /tmp/test /tmp/test.c 2>&1 && /tmp/test && echo COMPILE OK || echo COMPILE FAIL"

for mp in "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
