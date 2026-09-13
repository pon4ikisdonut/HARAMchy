#!/bin/bash
# Create a meson.build for hyprland-protocols subproject
HYPRDIR="/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/subprojects/hyprland-protocols"
cat > "$HYPRDIR/meson.build" << 'MESONEOF'
project(
  'hyprland-protocols',
  'c',
  version: '0.4.0',
)

pkg = import('pkgconfig')

install_data(
  'protocols/hyprland-toplevel-export-v1.xml',
  'protocols/hyprland-global-shortcuts-v1.xml',
  'protocols/hyprland-focus-grab-v1.xml',
  'protocols/hyprland-ctm-control-v1.xml',
  'protocols/hyprland-surface-v1.xml',
  'protocols/hyprland-lock-notify-v1.xml',
  'protocols/hyprland-toplevel-mapping-v1.xml',
  'protocols/hyprland-input-capture-v1.xml',
  install_dir: get_option('datadir') / 'hyprland-protocols' / 'protocols',
)

pkg.generate(
  name: 'hyprland-protocols',
  description: 'Hyprland protocol files',
  version: meson.project_version(),
  variables: [
    'pkgdatadir=${datadir}/hyprland-protocols',
  ],
)
MESONEOF

echo "Created meson.build for hyprland-protocols"
cat "$HYPRDIR/meson.build"
