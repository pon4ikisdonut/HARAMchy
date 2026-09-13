#!/bin/bash
echo 177695 | sudo -S bash -c '
mount --bind /home/lfs/src /home/lfs/lfs-root/sources 2>/dev/null
chroot /home/lfs/lfs-root /usr/bin/env -i PATH=/usr/bin:/bin LFS=/mnt/lfs /bin/bash -c "echo INSIDE_CHROOT; ls /sources/ | head -5; find /sources -maxdepth 1 -name tzdata*"
'