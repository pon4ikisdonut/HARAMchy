#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

# Restore host libs
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2"
cp -f /lib/x86_64-linux-gnu/libc.so.6 "$LFS/lib64/libc.so.6"
cp -f /lib/x86_64-linux-gnu/libc.so.6 "$LFS/lib/x86_64-linux-gnu/libc.so.6"
for lib in libc.so.6 libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libgmp.so.10 libselinux.so.1 libpcre2-8.so.0 libnss_dns.so.2 libnss_files.so.2; do
    cp -f /lib/x86_64-linux-gnu/$lib "$LFS/lib/x86_64-linux-gnu/$lib" 2>/dev/null
done
cp -f /bin/bash "$LFS/usr/bin/bash"

mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

echo "=== Shadow configure error ==="
cd "$LFS/tmp/build/shadow-4.14.5" 2>/dev/null && ./configure --prefix=/usr --disable-man --without-libpam --without-selinux 2>&1 | tail -30 || echo "shadow build dir missing"

echo "=== Sysvinit error ==="
cd "$LFS/tmp/build/sysvinit-3.07" 2>/dev/null && make 2>&1 | tail -20 || echo "sysvinit build dir missing"

for mp in "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
