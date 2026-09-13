#!/bin/bash
echo 177695 | sudo -S bash -c '
echo "=== Checking sourceware elfutils ==="
curl -s "https://sourceware.org/pub/elfutils/" | grep -oP "[0-9][0-9.]*/" | sort -V | tail -10

echo ""
echo "=== Checking 0.189 ==="
curl -sI --max-time 10 "https://sourceware.org/pub/elfutils/0.189/elfutils-0.189.tar.xz" | head -3

echo "=== Checking 0.188 ==="
curl -sI --max-time 10 "https://sourceware.org/pub/elfutils/0.188/elfutils-0.188.tar.xz" | head -3

echo "=== Checking 0.190 ==="
curl -sI --max-time 10 "https://sourceware.org/pub/elfutils/0.190/elfutils-0.190.tar.xz" | head -3

echo "=== Checking via curl download test ==="
curl -sL --max-time 30 "https://sourceware.org/pub/elfutils/0.189/elfutils-0.189.tar.xz" -o /dev/null -w "HTTP %{http_code}, size %{size_download}\n"

echo "=== Trying direct curl download for elfutils-0.190 ==="
curl -L --max-time 60 -o /home/lfs/src/elfutils-0.190-dl.tar.xz "https://sourceware.org/pub/elfutils/0.190/elfutils-0.190.tar.xz" 2>&1 | tail -3
ls -la /home/lfs/src/elfutils-0.190-dl.tar.xz
file /home/lfs/src/elfutils-0.190-dl.tar.xz
'
