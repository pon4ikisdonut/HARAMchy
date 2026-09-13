#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copying host GCC and deps into chroot ==="

# Copy gcc and its deps
for bin in gcc gcc-11 cc; do
    if [ -f "/usr/bin/$bin" ]; then
        cp -f "/usr/bin/$bin" "$LFS/usr/bin/$bin" 2>/dev/null
        echo "  Copied $bin"
    fi
done

# Copy libgcc_s, libstdc++, libgomp, libcc1 etc.
mkdir -p "$LFS/usr/lib/gcc/x86_64-linux-gnu/11"
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/cc1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/collect2 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/lto1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/lto-wrapper "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so.1 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libstdc++.so.6 "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libstdc++.so "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgomp.so* "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/liblto_plugin.so* "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
echo "  Copied GCC support files"

# Copy cpp (C preprocessor)
cp -f /usr/bin/cpp "$LFS/usr/bin/cpp" 2>/dev/null
echo "  Copied cpp"

# Copy as, ld, objcopy, objdump, strip from binutils
for bin in as ld objcopy objdump strip nm ar ranlib readelf; do
    cp -f "/usr/bin/$bin" "$LFS/usr/bin/$bin" 2>/dev/null
done
echo "  Copied binutils"

# Copy libgcc_s to lib
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so.1 "$LFS/lib64/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libstdc++.so.6 "$LFS/lib64/" 2>/dev/null

# Copy libgcc_s.so linker script
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null

# Fix the libgcc_s.so linker script path
sed -i "s|/usr/lib/gcc/x86_64-linux-gnu/11/|/usr/lib/gcc/x86_64-linux-gnu/11/|g" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so" 2>/dev/null

# Copy include files
mkdir -p "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/include"
cp -rf /usr/lib/gcc/x86_64-linux-gnu/11/include/* "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/include/" 2>/dev/null
echo "  Copied GCC headers"

# Copy machine specs
cp -f /usr/lib/gcc/x86_64-linux-gnu/11/specs "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null

echo "=== Done copying ==="
'
