#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2"
cp -f /lib/x86_64-linux-gnu/libc.so.6 "$LFS/lib64/libc.so.6"
cp -f /lib/x86_64-linux-gnu/libc.so.6 "$LFS/lib/x86_64-linux-gnu/libc.so.6"
for lib in libc.so.6 libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libgmp.so.10 libselinux.so.1 libpcre2-8.so.0 libnss_dns.so.2 libnss_files.so.2; do
    cp -f /lib/x86_64-linux-gnu/$lib "$LFS/lib/x86_64-linux-gnu/$lib" 2>/dev/null
done
cp -f /bin/bash "$LFS/usr/bin/bash"

mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash -c "
mkdir -p /tmp/build /var/log

echo \"=== shadow configure ===\"
rm -rf /tmp/build/shadow-4.14.5
cd /tmp/build && tar -xf /sources/shadow-4.14.5.tar.xz && cd shadow-4.14.5
./configure --prefix=/usr --bindir=/bin --sbindir=/sbin --sysconfdir=/etc --localstatedir=/var --disable-man --without-libpam --without-selinux --without-acl --without-attr --without-audit --without-nscd 2>&1 | tail -30
echo \"EXIT: \$?\"

echo \"=== sysvinit ===\"
rm -rf /tmp/build/sysvinit-3.07
cd /tmp/build && tar -xf /sources/sysvinit-3.07.tar.xz && cd sysvinit-3.07
make 2>&1 | tail -20
echo \"EXIT: \$?\"

echo \"=== procps-ng configure ===\"
rm -rf /tmp/build/procps-ng-4.0.3
cd /tmp/build && tar -xf /sources/procps-ng-4.0.3.tar.xz && cd procps-ng-4.0.3
./configure --prefix=/usr --disable-static --without-ncurses 2>&1 | tail -30
echo \"EXIT: \$?\"
"

for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
