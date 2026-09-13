#!/bin/bash
echo 177695 | sudo -S bash -c '
tar xf /home/lfs/src/pixman-0.42.2.tar.gz -C /tmp/ 2>/dev/null
cat /tmp/pixman-0.42.2/meson_options.txt 2>/dev/null
'
