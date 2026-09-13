#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Fixing /usr/lib/x86_64-linux-gnu ==="
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu"
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/usr/lib/x86_64-linux-gnu/"

# Copy all CRT objects and static libs there too
for f in Scrt1.o crti.o crtn.o crt1.o crtbegin.o crtbeginS.o crtbeginT.o crtend.o crtendS.o; do
    find "$LFS/lib/x86_64-linux-gnu" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11" -name "$f" 2>/dev/null | while read src; do
        cp -f "$src" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
    done
done

# Copy libc_nonshared.a to all lib paths
cp -f "$LFS/lib/x86_64-linux-gnu/libc_nonshared.a" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null

# Restore ALL host shared libs  
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2" 2>/dev/null
for src in /lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib64/$bn" 2>/dev/null
done

# Fix dangling symlinks
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then rm -f "$link"; cp -f "$real" "$link" 2>/dev/null; fi
    fi
done

# Write test file
cat > "$LFS/tmp/t.c" << CEOF
int main(){return 0;}
CEOF

mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux \
    PATH=/usr/bin:/bin:/sbin:/usr/sbin \
    /usr/bin/bash -c "
echo \"=== Test gcc link ===\"
gcc -o /tmp/t /tmp/t.c 2>&1
echo \"gcc_exit:\$?\"
echo \"=== Test which ===\"
/usr/bin/ls /usr/bin/mktemp /bin/mktemp /usr/bin/echo /bin/echo 2>&1
echo \"=== Test shadow configure ===\"
cd /tmp
if [ -d /tmp/build/shadow-4.14.5 ]; then
    cd /tmp/build/shadow-4.14.5
    ./configure --prefix=/usr --bindir=/bin --sbindir=/sbin --sysconfdir=/etc --localstatedir=/var --disable-man --without-libpam --without-selinux --without-acl --without-attr --without-audit --without-nscd --without-libbsd 2>&1 | tail -5
    echo \"shadow_configure:\$?\"
fi
"

for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys"; do
    umount "$mp" 2>/dev/null
done
'
