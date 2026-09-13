#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src

rm -f file-5.45.tar.gz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz libelf-0.190.tar.xz

echo "Trying github/mirror sources..."

# file - use a version that exists on github
wget -q "https://github.com/file/file/archive/refs/tags/file5.45.tar.gz" -O file-5.45.tar.gz 2>/dev/null && echo "OK: file (gh tag)" || \
wget -q "https://github.com/file/file/archive/refs/tags/file-5.45.tar.gz" -O file-5.45.tar.gz 2>/dev/null && echo "OK: file (gh tag2)" || \
{ echo "Trying 5.44..."; wget -q "https://astron.com/pub/file/file-5.44.tar.xz" 2>/dev/null && echo "OK: file-5.44"; } || echo "FAIL: file"

# gawk - try multiple GNU mirrors
wget -q "https://ftp.gnu.org/pub/gnu/gawk/gawk-6.0.0.tar.xz" -O gawk-6.0.0.tar.xz 2>/dev/null && echo "OK: gawk" || \
wget -q "https://ftpmirror.gnu.org/gawk/gawk-6.0.0.tar.xz" -O gawk-6.0.0.tar.xz 2>/dev/null && echo "OK: gawk (mirror)" || \
wget -q "https://mirrors.tuna.tsinghua.edu.cn/gnu/gawk/gawk-6.0.0.tar.xz" -O gawk-6.0.0.tar.xz 2>/dev/null && echo "OK: gawk (tsinghua)" || \
echo "FAIL: gawk"

# kbd
wget -q "https://mirrors.edge.kernel.org/pub/linux/utils/kbd/kbd-2.57.1.tar.xz" -O kbd-2.57.1.tar.xz 2>/dev/null && echo "OK: kbd (edge)" || \
wget -q "https://mirror.leaseweb.net/pub/linux/utils/kbd/kbd-2.57.1.tar.xz" -O kbd-2.57.1.tar.xz 2>/dev/null && echo "OK: kbd (leaseweb)" || \
echo "FAIL: kbd"

# elfutils
wget -q "https://sourceware.org/pub/elfutils/0.190/elfutils-0.190.tar.xz" -O libelf-0.190.tar.xz 2>/dev/null && echo "OK: libelf (pub)" || \
wget -q "https://sourceware.org/elfutils/ftp/0.190/elfutils-0.190.tar.xz" -O libelf-0.190.tar.xz 2>/dev/null && echo "OK: libelf (ftp)" || \
echo "FAIL: libelf"

echo ""
echo "=== Final ==="
for f in file-5.45.tar.gz file-5.44.tar.xz gawk-6.0.0.tar.xz kbd-2.57.1.tar.xz libelf-0.190.tar.xz; do
    if [ -s "$f" ]; then
        echo "  OK: $f ($(file -b "$f" | head -c 50))"
    elif [ -f "$f" ]; then
        echo "  EMPTY: $f"
    else
        echo "  MISSING: $f"
    fi
done
'
