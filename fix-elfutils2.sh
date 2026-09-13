#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src

rm -f elfutils-0.190.tar.xz elfutils-0.190-dl.tar.xz libelf-0.191.tar.xz libelf-0.189.tar.xz

echo "Downloading elfutils-0.192..."
curl -L --max-time 120 -o elfutils-0.192.tar.xz "https://sourceware.org/pub/elfutils/0.192/elfutils-0.192.tar.xz"
ls -la elfutils-0.192.tar.xz
file elfutils-0.192.tar.xz

echo ""
echo "=== Summary of all tarballs ==="
echo "Files that are NOT valid archives:"
for f in *.tar.*; do
    if ! file "$f" | grep -qE 'gzip|xz|bzip2|zstd|compress|tar'; then
        echo "  BAD: $f ($(file -b "$f" | head -c 50))"
    fi
done
echo ""
echo "Total good archives:"
count=0
for f in *.tar.*; do
    if file "$f" | grep -qE 'gzip|xz|bzip2|zstd|compress|tar'; then
        count=$((count+1))
    fi
done
echo "$count"
'
