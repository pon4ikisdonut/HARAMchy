#!/bin/bash
echo 177695 | sudo -S bash -c '
mount --bind /dev /home/lfs/lfs-root/dev 2>/dev/null
mount -t proc proc /home/lfs/lfs-root/proc 2>/dev/null
chroot /home/lfs/lfs-root /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /usr/bin/bash -c "which meson; which python3; python3 --version; meson --version; which cmake; cmake --version | head -1; which git; which wayland-scanner; echo PATH=\$PATH"
umount /home/lfs/lfs-root/dev 2>/dev/null
umount /home/lfs/lfs-root/proc 2>/dev/null
'
