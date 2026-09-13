#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Copying CRT objects and libgcc ==="

# CRT objects from glibc
for crt in Scrt1.o crti.o crtn.o; do
    src=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "$crt" 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
        cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
        echo "  $crt"
    fi
done

# CRTbegin/end objects from GCC
for crt in crtbeginS.o crtendS.o crtbeginT.o crtbegin.o crtend.o; do
    src=$(find /usr/lib/gcc/x86_64-linux-gnu/11 -name "$crt" 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
        echo "  $crt"
    fi
done

# libgcc.a and libgcc_s
for lib in libgcc.a libgcc_eh.a; do
    src=$(find /usr/lib/gcc/x86_64-linux-gnu/11 -name "$lib" 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
        echo "  $lib"
    fi
done

# libgcc_s.so linker script fix - point to correct location
cat > "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so" << LIBGCC
/* GNU ld script */
OUTPUT_FORMAT(elf64-x86-64)
GROUP ( /usr/lib/gcc/x86_64-linux-gnu/11/libgcc_s.so.1 )
LIBGCC
echo "  Fixed libgcc_s.so linker script"

# Also copy libgcc_s.so.1 to the GCC lib dir
cp -f "$LFS/lib64/libgcc_s.so.1" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null

# libpthread.a, libc.a etc. for static linking
for lib in libc_nonshared.a libpthread_nonshared.a; do
    src=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "$lib" 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp -f "$src" "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
        cp -f "$src" "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
        echo "  $lib"
    fi
done

# libc.so linker script  
cat > "$LFS/lib64/libc.so" << LIBCSO
/* GNU ld script */
OUTPUT_FORMAT(elf64-x86-64)
GROUP ( /lib64/libc.so.6 /lib64/libpthread.so.0 )
LIBCSO
echo "  Fixed libc.so linker script"

echo "=== Done ==="
'
