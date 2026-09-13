#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src

rm -f bzip2-1.0.8.tar.gz file-5.45.tar.xz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz kmod-31.tar.xz libelf-0.190.tar.xz man-db-2.12.0.tar.xz zlib-1.3.tar.gz

echo "Downloading..."
wget -q -c "https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz" && echo "OK: bzip2" || echo "FAIL: bzip2"
wget -q -c "https://astron.com/pub/file/file-5.45.tar.xz" && echo "OK: file" || echo "FAIL: file"
wget -q -c "https://ftp.gnu.org/gnu/gawk/gawk-6.0.0.tar.xz" && echo "OK: gawk" || echo "FAIL: gawk"
wget -q -c "https://www.kernel.org/pub/linux/utils/kbd/kbd-2.57.1.tar.xz" && echo "OK: kbd" || echo "FAIL: kbd"
wget -q -c "https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-31.tar.xz" && echo "OK: kmod" || echo "FAIL: kmod"
wget -q -c "https://sourceware.org/ftp/elfutils/0.190/elfutils-0.190.tar.xz" && echo "OK: libelf" || echo "FAIL: libelf"
wget -q -c "https://download.savannah.gnu.org/releases/man-db/man-db-2.12.0.tar.xz" && echo "OK: man-db" || echo "FAIL: man-db"
wget -q -c "https://zlib.net/fossils/zlib-1.2.13.tar.xz" -O zlib-1.2.13.tar.xz && echo "OK: zlib" || echo "FAIL: zlib"

echo ""
echo "=== Verify ==="
for f in bzip2-1.0.8.tar.gz file-5.45.tar.xz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz kmod-31.tar.xz libelf-0.190.tar.xz man-db-2.12.0.tar.xz zlib-1.2.13.tar.xz; do
    file "$f" | sed "s|.*/||"
done
'
