#!/bin/bash
echo 177695 | sudo -S bash -c '
echo "=== DNS ==="
cat /etc/resolv.conf 2>/dev/null | head -3

echo "=== Basic connectivity ==="
curl -sI --max-time 5 https://www.google.com 2>&1 | head -1
curl -sI --max-time 5 https://ftp.gnu.org 2>&1 | head -1
curl -sI --max-time 5 https://kernel.org 2>&1 | head -1

echo "=== Trying curl for downloads ==="
cd /home/lfs/src

curl -L --max-time 30 -o /dev/null -w "%{http_code}" "https://ftp.gnu.org/gnu/gawk/gawk-6.0.0.tar.xz" 2>/dev/null
echo " gawk"

curl -L --max-time 30 -o /dev/null -w "%{http_code}" "https://www.kernel.org/pub/linux/utils/kbd/kbd-2.57.1.tar.xz" 2>/dev/null
echo " kbd"

curl -L --max-time 30 -o /dev/null -w "%{http_code}" "https://sourceware.org/pub/elfutils/0.190/elfutils-0.190.tar.xz" 2>/dev/null
echo " elfutils"

curl -L --max-time 30 -o /dev/null -w "%{http_code}" "https://astron.com/pub/file/file-5.45.tar.xz" 2>/dev/null
echo " file"

curl -L --max-time 30 -o /dev/null -w "%{http_code}" "https://github.com" 2>/dev/null
echo " github"
'
