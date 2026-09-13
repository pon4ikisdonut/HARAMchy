#!/bin/bash
sed -i "s|run_command('ln', '-s'|run_command('ln', '-sf'|g" /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/subprojects/wlroots/include/meson.build
head -5 /home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/subprojects/wlroots/include/meson.build
