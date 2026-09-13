#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src
rm -f zlib-1.2.13.tar.xz file-5.45.tar.xz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz libelf-0.190.tar.xz

echo "Trying alternate mirrors..."

# file-5.45
wget -q -c "https://astron.com/pub/file/file-5.45.tar.xz" 2>/dev/null && echo "OK: file (astron)" || \
wget -q -c "https://github.com/file/file/archive/refs/tags/file-5.45.tar.gz" -O file-5.45.tar.gz 2>/dev/null && echo "OK: file (github)" || \
wget -q -c "https://fossies.org/linux/misc/file-5.45.tar.xz" 2>/dev/null && echo "OK: file (fossies)" || echo "FAIL: file"

# gawk-6.0.0
wget -q -c "https://ftp.gnu.org/gnu/gawk/gawk-6.0.0.tar.xz" 2>/dev/null && echo "OK: gawk (gnu)" || \
wget -q -c "https://mirror.kakao.com/gnu/gawk/gawk-6.0.0.tar.xz" 2>/dev/null && echo "OK: gawk (kakao)" || \
wget -q -c "https://ftp.kr.freebsd.org/pub/gnu/gawk/gawk-6.0.0.tar.xz" 2>/dev/null && echo "OK: gawk (freebsd)" || echo "FAIL: gawk"

# kbd-2.57.1
wget -q -c "https://www.kernel.org/pub/linux/utils/kbd/kbd-2.57.1.tar.xz" 2>/dev/null && echo "OK: kbd (kernel.org)" || \
wget -q -c "https://cdn.kernel.org/pub/linux/utils/kbd/kbd-2.57.1.tar.xz" 2>/dev/null && echo "OK: kbd (cdn)" || echo "FAIL: kbd"

# libelf-0.190
wget -q -c "https://sourceware.org/ftp/elfutils/0.190/elfutils-0.190.tar.xz" 2>/dev/null && echo "OK: libelf (sourceware)" || \
wget -q -c "https://sourceware.org/pub/elfutils/0.190/elfutils-0.190.tar.xz" 2>/dev/null && echo "OK: libelf (pub)" || echo "FAIL: libelf"

# zlib-1.3 - try 1.2.13 which is the LFS standard
rm -f zlib-1.2.13.tar.xz
wget -q -c "https://zlib.net/fossils/zlib-1.2.13.tar.gz" -O zlib-1.2.13.tar.gz 2>/dev/null && echo "OK: zlib (gz)" || \
wget -q -c "https://github.com/madler/zlib/releases/download/v1.2.13/zlib-1.2.13.tar.gz" -O zlib-1.2.13.tar.gz 2>/dev/null && echo "OK: zlib (github)" || echo "FAIL: zlib"

echo ""
echo "=== Final check ==="
for f in bzip2-1.0.8.tar.gz file-5.45.tar.xz file-5.45.tar.gz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz kmod-31.tar.xz libelf-0.190.tar.xz man-db-2.12.0.tar.xz zlib-1.2.13.tar.gz; do
    if [ -f "$f" ]; then
        echo "  EXISTS: $f ($(file -b "$f" | head -c 40))"
    fi
done
'
