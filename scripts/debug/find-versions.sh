#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src

echo "=== Finding available versions ==="
echo "gawk versions:"
curl -s "https://ftp.gnu.org/gnu/gawk/" | grep -oP "gawk-[0-9][^\"<]+" | sort -V | tail -5

echo "kbd versions:"
curl -s "https://www.kernel.org/pub/linux/utils/kbd/" | grep -oP "kbd-[0-9][^\"<]+" | sort -V | tail -5

echo "elfutils versions:"
curl -s "https://sourceware.org/pub/elfutils/" | grep -oP "[0-9][0-9.]+/" | sort -V | tail -5

echo "file versions:"
curl -s "https://astron.com/pub/file/" | grep -oP "file-[0-9][^\"<]+" | sort -V | tail -5
'
