#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src
rm -f file-5.45.tar.gz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz libelf-0.190.tar.xz

echo "Downloading from working sources..."

# gawk - use 5.4.1 (latest on GNU mirrors)
wget -q "https://ftp.gnu.org/gnu/gawk/gawk-5.4.1.tar.xz" -O gawk-5.4.1.tar.xz && echo "OK: gawk-5.4.1" || echo "FAIL: gawk"

# kbd - use 2.10.0 (latest on kernel.org)
wget -q "https://www.kernel.org/pub/linux/utils/kbd/kbd-2.10.0.tar.xz" -O kbd-2.10.0.tar.xz && echo "OK: kbd-2.10.0" || echo "FAIL: kbd"

# elfutils/libelf - use 0.190 from archive or 0.191
wget -q "https://sourceware.org/pub/elfutils/0.191/elfutils-0.191.tar.xz" -O libelf-0.191.tar.xz 2>/dev/null && echo "OK: libelf-0.191" || \
wget -q "https://sourceware.org/pub/elfutils/0.189/elfutils-0.189.tar.xz" -O libelf-0.189.tar.xz 2>/dev/null && echo "OK: libelf-0.189" || echo "FAIL: libelf"

# file - use 5.48 (latest available)
wget -q "https://astron.com/pub/file/file-5.48.tar.gz" -O file-5.48.tar.gz && echo "OK: file-5.48" || echo "FAIL: file"

echo ""
echo "=== Verify ==="
for f in gawk-5.4.1.tar.xz kbd-2.10.0.tar.xz file-5.48.tar.gz libelf-0.191.tar.xz libelf-0.189.tar.xz; do
    if [ -s "$f" ]; then
        echo "  OK: $f ($(file -b "$f" | head -c 40))"
    elif [ -f "$f" ]; then
        echo "  EMPTY: $f"
    fi
done

echo ""
echo "=== Tarball inventory ==="
ls -1 *.tar.* | wc -l
echo "tarballs present"
ls -1 *.tar.*
'
