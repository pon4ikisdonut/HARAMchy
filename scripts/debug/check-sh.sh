#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux \
    PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    /usr/bin/bash -c "
ls -la /bin/sh 2>&1
ls -la /usr/bin/sh 2>&1
ls -la /bin/echo /usr/bin/echo /bin/mktemp /usr/bin/mktemp 2>&1
ls /tmp/build/ 2>&1
"

for mp in "$LFS/sources" "$LFS/dev" "$LFS/proc" "$LFS/sys"; do
    umount "$mp" 2>/dev/null
done
'
