#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root
CROSS=$LFS/tools/bin/x86_64-lfs-linux-gnu-gcc
SYSROOT=$LFS

# Use -static directly without going through configure
# The problem is configure overrides CC. Lets fix the approach.
cd /home/lfs/build

echo "=== Building static gawk ==="
rm -rf gawk-6.0.0-static2
tar -xf /home/lfs/src/gawk-6.0.0.tar.xz
mv gawk-6.0.0 gawk-6.0.0-static2
cd gawk-6.0.0-static2

CC="$CROSS" \
CFLAGS="--sysroot=$SYSROOT -static" \
LDFLAGS="--sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) LDFLAGS="-static" 2>&1 | tail -10
if [ -f gawk ]; then
    echo "gawk built!"
    file gawk
    cp -f gawk $LFS/usr/bin/gawk
    ln -sf gawk $LFS/usr/bin/awk
else
    echo "gawk build failed"
fi

cd /home/lfs/build
echo "=== Building static m4 ==="
rm -rf m4-1.4.19-static2
tar -xf /home/lfs/src/m4-1.4.19.tar.xz
mv m4-1.4.19 m4-1.4.19-static2
cd m4-1.4.19-static2

CC="$CROSS" \
CFLAGS="--sysroot=$SYSROOT -static" \
LDFLAGS="--sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) LDFLAGS="-static" 2>&1 | tail -10
if [ -f src/m4 ]; then
    echo "m4 built!"
    file src/m4
    cp -f src/m4 $LFS/usr/bin/m4
else
    echo "m4 build failed"
fi

cd /home/lfs/build
echo "=== Building static bison ==="
rm -rf bison-3.8.2-static2
tar -xf /home/lfs/src/bison-3.8.2.tar.xz
mv bison-3.8.2 bison-3.8.2-static2
cd bison-3.8.2-static2

CC="$CROSS" \
CFLAGS="--sysroot=$SYSROOT -static" \
LDFLAGS="--sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) LDFLAGS="-static" 2>&1 | tail -10
if [ -f src/bison ]; then
    echo "bison built!"
    file src/bison
    cp -f src/bison $LFS/usr/bin/bison
else
    echo "bison build failed"
fi

cd /home/lfs/build
echo "=== Building static flex ==="
rm -rf flex-2.6.4-static
tar -xf /home/lfs/src/flex-2.6.4.tar.gz
mv flex-2.6.4 flex-2.6.4-static
cd flex-2.6.4-static

CC="$CROSS" \
CFLAGS="--sysroot=$SYSROOT -static" \
LDFLAGS="--sysroot=$SYSROOT -static" \
./configure \
    --prefix=/usr \
    --host=x86_64-lfs-linux-gnu \
    --disable-nls \
    2>&1 | tail -5

make -j$(nproc) LDFLAGS="-static" 2>&1 | tail -10
if [ -f src/flex ]; then
    echo "flex built!"
    file src/flex
    cp -f src/flex $LFS/usr/bin/flex
    ln -sf flex $LFS/usr/bin/lex
else
    echo "flex build failed"
fi

echo ""
echo "=== Final check ==="
for cmd in bash sh tar gzip xz find diff sed grep gawk m4 bison flex make; do
    f=""
    for p in $LFS/usr/bin/$cmd $LFS/bin/$cmd; do
        if [ -x "$p" ]; then f="$p"; break; fi
    done
    if [ -n "$f" ]; then
        echo "  OK: $cmd ($(file -b "$f" | head -c 50))"
    else
        echo "  MISSING: $cmd"
    fi
done
'
