#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

# Copy host bash as the real binary
cp -f /bin/bash "$LFS/usr/bin/bash"
cp -f /bin/bash "$LFS/bin/bash"

# Restore host libs
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2"
cp -f /lib/x86_64-linux-gnu/libc.so.6 "$LFS/lib64/libc.so.6"
mkdir -p "$LFS/lib/x86_64-linux-gnu"
for lib in libc.so.6 libtinfo.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libresolv.so.2 libgmp.so.10 libselinux.so.1 libpcre2-8.so.0 libnss_dns.so.2 libnss_files.so.2; do
    cp -f /lib/x86_64-linux-gnu/$lib "$LFS/lib/x86_64-linux-gnu/$lib" 2>/dev/null
    cp -f /lib/x86_64-linux-gnu/$lib "$LFS/lib64/$lib" 2>/dev/null
done

# Mount
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

# Verify bash works
echo "=== Testing bash ==="
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/bash -c "echo OK: bash works; uname -a"

# Debug shadow
echo "=== Shadow configure check ==="
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/bin LFS=/mnt/lfs /usr/bin/bash -c "
ls /tmp/build/shadow-4.14.5/configure 2>/dev/null && echo configure exists || echo configure missing
cat /tmp/build/shadow-4.14.5/config.log 2>/dev/null | tail -20
"

# Cleanup
for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
