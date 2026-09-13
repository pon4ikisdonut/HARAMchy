#!/bin/bash
echo 177695 | sudo -S bash -c '
cd /home/lfs/src
echo "=== Checking critical tarballs ==="
for f in tzdata2023c.tar.gz iana-etc-20230810.tar.gz man-db-2.12.0.tar.xz groff-1.23.0.tar.gz pkgconf-2.0.1.tar.xz bzip2-1.0.8.tar.gz xz-5.4.5.tar.xz zstd-1.5.5.tar.gz file-5.48.tar.gz ncurses-6.4.tar.gz sed-4.9.tar.xz psmisc-23.6.tar.xz gettext-0.22.3.tar.xz bison-3.8.2.tar.xz perl-5.38.0.tar.xz Python-3.11.6.tar.xz texinfo-7.1.tar.xz util-linux-2.39.1.tar.xz kmod-31.tar.xz libtool-2.4.7.tar.xz make-4.3.tar.gz coreutils-9.4.tar.xz diffutils-3.10.tar.xz findutils-4.9.0.tar.xz gawk-5.4.1.tar.xz grep-3.11.tar.xz gzip-1.13.tar.xz tar-1.35.tar.xz bash-5.2.21.tar.gz; do
    if [ -s "$f" ] && file "$f" | grep -qi compress; then
        echo "  OK: $f"
    elif [ -s "$f" ]; then
        echo "  BAD: $f ($(file -b "$f" | head -c 40))"
    else
        echo "  MISSING/EMPTY: $f"
    fi
done
'
