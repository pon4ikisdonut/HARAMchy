#!/bin/bash
set -e
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
CROSS=$LFS/tools/bin/x86_64-lfs-linux-gnu-gcc
SRC=/home/lfs/build
SYSROOT=$LFS

# Build static bash
echo "=== Building static bash ==="
cd $SRC
rm -rf bash-5.2.21-static
tar -xf /home/lfs/src/bash-5.2.21.tar.gz
mv bash-5.2.21 bash-5.2.21-static
cd bash-5.2.21-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --without-bash-malloc \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools 2>&1 | tail -3

echo "=== Static bash built ==="
ls -la /tmp/static-tools/usr/bin/bash 2>/dev/null

# Install into chroot
cp -f /tmp/static-tools/usr/bin/bash $LFS/bin/bash
ln -sf bash $LFS/bin/sh
cp -f /tmp/static-tools/usr/bin/bash $LFS/usr/bin/bash

echo "=== Testing chroot with static bash ==="
$LFS/bin/sh -c "echo STATIC-BASH-OK"

# Now build coreutils (static)
echo "=== Building static coreutils ==="
cd $SRC
rm -rf coreutils-9.4-static
tar -xf /home/lfs/src/coreutils-9.4.tar.xz
mv coreutils-9.4 coreutils-9.4-static
cd coreutils-9.4-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    --disable-xattr \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-coreutils 2>&1 | tail -3

echo "=== Installing coreutils into chroot ==="
for cmd in cat chmod chown chgrp cp date dd df echo expr head install ln ls mkdir mknod mktemp mv nice nohup od pinky printenv pwd readlink rm rmdir seq sleep sort stty tail tee touch tr tty uname uniq wc; do
    if [ -f /tmp/static-tools-coreutils/usr/bin/$cmd ]; then
        cp -f /tmp/static-tools-coreutils/usr/bin/$cmd $LFS/usr/bin/$cmd
    fi
done
cp -f /tmp/static-tools-coreutils/usr/bin/coreutils $LFS/usr/bin/coreutils 2>/dev/null

echo "=== Building static tar ==="
cd $SRC
rm -rf tar-1.35-static
tar -xf /home/lfs/src/tar-1.35.tar.xz
mv tar-1.35 tar-1.35-static
cd tar-1.35-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-tar 2>&1 | tail -3
cp -f /tmp/static-tools-tar/usr/bin/tar $LFS/usr/bin/tar
cp -f /tmp/static-tools-tar/usr/bin/xz $LFS/usr/bin/xz 2>/dev/null

echo "=== Building static gzip ==="
cd $SRC
rm -rf gzip-1.13-static
tar -xf /home/lfs/src/gzip-1.13.tar.xz
mv gzip-1.13 gzip-1.13-static
cd gzip-1.13-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-gzip 2>&1 | tail -3
cp -f /tmp/static-tools-gzip/usr/bin/gzip $LFS/usr/bin/gzip
cp -f /tmp/static-tools-gzip/usr/bin/gunzip $LFS/usr/bin/gunzip 2>/dev/null
cp -f /tmp/static-tools-gzip/usr/bin/zcat $LFS/usr/bin/zcat 2>/dev/null

echo "=== Building static xz ==="
cd $SRC
rm -rf xz-5.4.5-static
tar -xf /home/lfs/src/xz-5.4.5.tar.xz
mv xz-5.4.5 xz-5.4.5-static
cd xz-5.4.5-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-xz 2>&1 | tail -3
cp -f /tmp/static-tools-xz/usr/bin/xz $LFS/usr/bin/xz
cp -f /tmp/static-tools-xz/usr/bin/unxz $LFS/usr/bin/unxz 2>/dev/null
cp -f /tmp/static-tools-xz/usr/bin/xzcat $LFS/usr/bin/xzcat 2>/dev/null

echo "=== Building static findutils ==="
cd $SRC
rm -rf findutils-4.9.0-static
tar -xf /home/lfs/src/findutils-4.9.0.tar.xz
mv findutils-4.9.0 findutils-4.9.0-static
cd findutils-4.9.0-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-findutils 2>&1 | tail -3
cp -f /tmp/static-tools-findutils/usr/bin/find $LFS/usr/bin/find
cp -f /tmp/static-tools-findutils/usr/bin/xargs $LFS/usr/bin/xargs 2>/dev/null

echo "=== Building static diffutils ==="
cd $SRC
rm -rf diffutils-3.10-static
tar -xf /home/lfs/src/diffutils-3.10.tar.xz
mv diffutils-3.10 diffutils-3.10-static
cd diffutils-3.10-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-diffutils 2>&1 | tail -3
for cmd in diff cmp diff3 sdiff; do
    cp -f /tmp/static-tools-diffutils/usr/bin/$cmd $LFS/usr/bin/$cmd 2>/dev/null
done

echo "=== Building static sed ==="
cd $SRC
rm -rf sed-4.9-static
tar -xf /home/lfs/src/sed-4.9.tar.xz
mv sed-4.9 sed-4.9-static
cd sed-4.9-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-sed 2>&1 | tail -3
cp -f /tmp/static-tools-sed/usr/bin/sed $LFS/usr/bin/sed

echo "=== Building static gawk ==="
cd $SRC
rm -rf gawk-6.0.0-static
tar -xf /home/lfs/src/gawk-6.0.0.tar.xz
mv gawk-6.0.0 gawk-6.0.0-static
cd gawk-6.0.0-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-gawk 2>&1 | tail -3
cp -f /tmp/static-tools-gawk/usr/bin/gawk $LFS/usr/bin/gawk
ln -sf gawk $LFS/usr/bin/awk 2>/dev/null

echo "=== Building static grep ==="
cd $SRC
rm -rf grep-3.11-static
tar -xf /home/lfs/src/grep-3.11.tar.xz
mv grep-3.11 grep-3.11-static
cd grep-3.11-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-grep 2>&1 | tail -3
for cmd in grep egrep fgrep; do
    cp -f /tmp/static-tools-grep/usr/bin/$cmd $LFS/usr/bin/$cmd 2>/dev/null
done

echo "=== Building static patch ==="
cd $SRC
rm -rf patch-2.7.6-static
tar -xf /home/lfs/src/patch-2.7.6.tar.xz
mv patch-2.7.6 patch-2.7.6-static
cd patch-2.7.6-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-patch 2>&1 | tail -3
cp -f /tmp/static-tools-patch/usr/bin/patch $LFS/usr/bin/patch

echo "=== Building static bison ==="
cd $SRC
rm -rf bison-3.8.2-static
tar -xf /home/lfs/src/bison-3.8.2.tar.xz
mv bison-3.8.2 bison-3.8.2-static
cd bison-3.8.2-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-bison 2>&1 | tail -3
cp -f /tmp/static-tools-bison/usr/bin/bison $LFS/usr/bin/bison
cp -f /tmp/static-tools-bison/usr/bin/yacc $LFS/usr/bin/yacc 2>/dev/null

echo "=== Building static m4 ==="
cd $SRC
rm -rf m4-1.4.19-static
tar -xf /home/lfs/src/m4-1.4.19.tar.xz
mv m4-1.4.19 m4-1.4.19-static
cd m4-1.4.19-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-m4 2>&1 | tail -3
cp -f /tmp/static-tools-m4/usr/bin/m4 $LFS/usr/bin/m4

echo "=== Building static make ==="
cd $SRC
rm -rf make-4.3-static
tar -xf /home/lfs/src/make-4.3.tar.gz
mv make-4.3 make-4.3-static
cd make-4.3-static

CC="$CROSS --sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install DESTDIR=/tmp/static-tools-make 2>&1 | tail -3
cp -f /tmp/static-tools-make/usr/bin/make $LFS/usr/bin/make

echo ""
echo "=== SUMMARY ==="
echo "Static tools installed in chroot:"
for cmd in bash sh tar gzip gunzip xz find xargs diff sed gawk grep patch bison m4 make cat ls cp mv rm mkdir; do
    if [ -x "$LFS/usr/bin/$cmd" ] || [ -x "$LFS/bin/$cmd" ]; then
        echo "  OK: $cmd"
    else
        echo "  MISSING: $cmd"
    fi
done
'
