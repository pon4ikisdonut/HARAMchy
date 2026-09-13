#!/bin/bash
echo 177695 | sudo -S bash -c '
tar xf /home/lfs/src/xkbcommon-1.5.0.tar.gz -C /tmp/ 2>/dev/null
cat /tmp/libxkbcommon-xkbcommon-1.5.0/meson_options.txt 2>/dev/null
'
