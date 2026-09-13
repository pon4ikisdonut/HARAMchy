#!/bin/bash
echo 177695 | sudo -S bash -c '
LFS=/home/lfs/lfs-root

echo "=== Step 1: Replace headers with host-consistent set ==="
rm -rf "$LFS/usr/include.bak"
mv "$LFS/usr/include" "$LFS/usr/include.bak" 2>/dev/null
cp -r /usr/include "$LFS/usr/include"
for dir in linux asm asm-generic asm-x86; do
    [ -d "$LFS/usr/include.bak/$dir" ] && cp -r "$LFS/usr/include.bak/$dir" "$LFS/usr/include/" 2>/dev/null
done
rm -rf "$LFS/usr/include.bak" 2>/dev/null

echo "=== Step 2: Copy ALL host shared libs ==="
cp -f /lib64/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null
for src in /lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib64/$bn" 2>/dev/null
done
for src in /usr/lib/x86_64-linux-gnu/*.so*; do
    bn=$(basename "$src")
    cp -f "$src" "$LFS/usr/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib/x86_64-linux-gnu/$bn" 2>/dev/null
    cp -f "$src" "$LFS/lib64/$bn" 2>/dev/null
done
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu"
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /lib/x86_64-linux-gnu/libc_nonshared.a "$LFS/lib/x86_64-linux-gnu/" 2>/dev/null

echo "=== Step 3: Fix dangling symlinks ==="
find "$LFS/lib" "$LFS/lib64" "$LFS/usr/lib" -type l 2>/dev/null | while read link; do
    if [ ! -e "$link" ]; then
        bn=$(basename "$link")
        real=$(find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -name "$bn" -not -type l 2>/dev/null | head -1)
        if [ -n "$real" ]; then rm -f "$link"; cp -f "$real" "$link" 2>/dev/null; fi
    fi
done

echo "=== Step 4: Copy essential binaries ==="
for tool in echo mktemp cat ls chmod chown date dd head install ln mkdir mknod mkfifo rm rmdir tail touch env nproc seq test timeout truncate wc arch basename comm cut dirname expand fmt fold id join logname md5sum nice nohup od paste pr printenv readlink realpath shuf sort tac tee tr tsort uniq unlink which find xargs diff file gawk awk mawk nawk cmp pkg-config ld as ar objcopy objdump ranlib nm strip readelf cmake ninja meson python3 python3.10 g++ g++-11 git wayland-scanner curl wget bison byacc; do
    src=$(which "$tool" 2>/dev/null)
    if [ -n "$src" ] && [ -f "$src" ]; then
        cp -f "$src" "$LFS/usr/bin/$tool" 2>/dev/null
    fi
done
rm -f "$LFS/bin/echo"; ln -sf /usr/bin/echo "$LFS/bin/echo"
rm -f "$LFS/bin/mktemp"; ln -sf /usr/bin/mktemp "$LFS/bin/mktemp"
cp -f /bin/bash "$LFS/usr/bin/bash" 2>/dev/null

echo "=== Step 5: Restore GCC/G++ ==="
cp -f /usr/bin/gcc "$LFS/usr/bin/gcc" 2>/dev/null
cp -f /usr/bin/cc "$LFS/usr/bin/cc" 2>/dev/null
cp -f /usr/bin/g++ "$LFS/usr/bin/g++" 2>/dev/null
cp -f /usr/bin/g++-11 "$LFS/usr/bin/g++-11" 2>/dev/null
for f in cc1 cc1plus collect2 libgcc_s.so.1 libgcc.a crtbeginS.o crtendS.o crtbeginT.o crtbegin.o crtend.o lto-wrapper lto1 liblto_plugin.so; do
    src=$(find /usr/lib/gcc/x86_64-linux-gnu/11 -name "$f" 2>/dev/null | head -1)
    [ -n "$src" ] && cp -f "$src" "$LFS/usr/lib/gcc/x86_64-linux-gnu/11/" 2>/dev/null
done

echo "=== Step 6: Fix libstdc++ ==="
rm -f "$LFS/usr/lib/libstdc++.la" "$LFS/usr/lib/libstdc++exp."* "$LFS/usr/lib/libstdc++fs."*
cp -f /usr/lib/x86_64-linux-gnu/libstdc++.so.6 "$LFS/usr/lib/libstdc++.so.6" 2>/dev/null
ln -sf libstdc++.so.6 "$LFS/usr/lib/libstdc++.so" 2>/dev/null

echo "=== Step 7: Copy Python stdlib ==="
rm -rf "$LFS/usr/lib/python3.10"
cp -r /usr/lib/python3.10 "$LFS/usr/lib/python3.10" 2>/dev/null

echo "=== Step 8: Copy ALL .pc files ==="
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig" "$LFS/usr/share/pkgconfig" "$LFS/usr/share/aclocal"
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/*.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
cp -f /usr/share/pkgconfig/*.pc "$LFS/usr/share/pkgconfig/" 2>/dev/null
cp -f /usr/share/aclocal/pkg.m4 "$LFS/usr/share/aclocal/" 2>/dev/null

echo "=== Step 9: Copy OpenGL/EGL ==="
for dir in GL EGL GLES GLES2 GLES3 KHR; do
    mkdir -p "$LFS/usr/include/$dir"
    cp -r /usr/include/$dir/* "$LFS/usr/include/$dir/" 2>/dev/null
done
cp -f /usr/lib/x86_64-linux-gnu/libEGL.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libGL.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libGLESv1_CM.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libGLESv2.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libGLdispatch.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libGLX.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libOpenGL.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libwayland-client.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libwayland-server.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libwayland-egl.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libwayland-cursor.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libdrm.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libgbm.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libinput.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libseat.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxkbcommon.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libxml2.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libicu*.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/liblzma.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libzstd.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/libffi.so* "$LFS/usr/lib/x86_64-linux-gnu/" 2>/dev/null
mkdir -p "$LFS/usr/lib/x86_64-linux-gnu/dri"
cp -f /usr/lib/x86_64-linux-gnu/dri/*.so "$LFS/usr/lib/x86_64-linux-gnu/dri/" 2>/dev/null

echo "=== Step 9b: Patch wayland version to 1.22.0 ==="
for dir in "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig" "$LFS/usr/lib/pkgconfig"; do
    for f in "$dir"/wayland-*.pc; do
        [ -f "$f" ] || continue
        sed -i "s/^Version:.*/Version: 1.22.0/" "$f"
    done
done

echo "=== Step 9c: Copy hwdata and libxml2 ==="
cp -r /usr/share/hwdata "$LFS/usr/share/" 2>/dev/null
cp -r /usr/include/libxml2 "$LFS/usr/include/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/libxml-2.0.pc "$LFS/usr/lib/x86_64-linux-gnu/pkgconfig/" 2>/dev/null
cp -f /usr/lib/x86_64-linux-gnu/pkgconfig/libxml-2.0.pc "$LFS/usr/lib/pkgconfig/" 2>/dev/null
# Copy git remote-https helper
mkdir -p "$LFS/usr/lib/git-core"
cp -r /usr/lib/git-core/* "$LFS/usr/lib/git-core/" 2>/dev/null
for f in $(find /usr/lib/git-core -name "git-remote-https*" 2>/dev/null); do
    cp -f "$f" "$LFS/usr/lib/git-core/" 2>/dev/null
done
cp -f /usr/lib/git-core/git-remote-https "$LFS/usr/libexec/git-core/git-remote-https" 2>/dev/null
cp -f /usr/lib/git-core/git-remote-http "$LFS/usr/libexec/git-core/git-remote-http" 2>/dev/null
mkdir -p "$LFS/usr/libexec/git-core"
cp -r /usr/lib/git-core/* "$LFS/usr/libexec/git-core/" 2>/dev/null

echo "=== Step 10: Clear log and markers ==="
rm -rf "$LFS/home/lfs/.build-markers/wayland/"*
rm -f "$LFS/var/log/haramchy-wayland.log"
touch "$LFS/var/log/haramchy-wayland.log"

echo "=== Step 11: Mount ==="
mount --bind /home/lfs/src "$LFS/sources" 2>/dev/null
mount --bind /dev "$LFS/dev" 2>/dev/null
mount --bind /dev/pts "$LFS/dev/pts" 2>/dev/null
mount -t proc proc "$LFS/proc" 2>/dev/null
mount -t sysfs sysfs "$LFS/sys" 2>/dev/null
mount -t tmpfs tmpfs "$LFS/run" 2>/dev/null

echo "=== Step 12: Verify ==="
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin /usr/bin/bash -c "cmake --version | head -1; meson --version; g++ --version | head -1; git --version; wayland-scanner --version 2>&1 | head -1; pkg-config --list-all 2>/dev/null | grep -cE \"wayland|egl|gl \" || echo 0"

echo "=== Step 13: Run ==="
# Pre-clone Hyprland submodules on HOST since git cannot clone inside chroot
mkdir -p /tmp/hyprland-submods
cd /tmp/hyprland-submods
if [ ! -d hyprland-protocols ]; then
    echo "  Cloning hyprland-protocols..."
    git clone --depth=1 https://github.com/hyprwm/hyprland-protocols 2>/dev/null
fi
if [ ! -d udis86 ]; then
    echo "  Cloning udis86..."
    git clone --depth=1 https://github.com/canihavesomecoffee/udis86 2>/dev/null
fi
cp /mnt/e/projects/haramchy/build-wayland-stack.sh "$LFS/home/lfs/build-wayland-stack.sh"
chmod +x "$LFS/home/lfs/build-wayland-stack.sh"
mkdir -p "$LFS/tmp/build"
# Copy pre-cloned submodules to sources dir so build script can find them
mkdir -p "$LFS/sources/hyprland-submods"
cp -r /tmp/hyprland-submods/hyprland-protocols "$LFS/sources/hyprland-submods/" 2>/dev/null
cp -r /tmp/hyprland-submods/udis86 "$LFS/sources/hyprland-submods/" 2>/dev/null

chroot "$LFS" /usr/bin/env -i HOME=/root TERM=linux PATH=/usr/bin:/bin:/sbin:/usr/sbin LFS=/mnt/lfs /usr/bin/bash /home/lfs/build-wayland-stack.sh 2>&1

for mp in "$LFS/sources" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    umount "$mp" 2>/dev/null
done
'
