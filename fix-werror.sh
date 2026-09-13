#!/bin/bash
sed -i "s/'werror=true'/'werror=false'/" /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/subprojects/wlroots/meson.build
grep 'werror' /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/subprojects/wlroots/meson.build
