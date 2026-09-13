#!/bin/bash
python3 << 'PYEOF'
with open("/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/meson.build", "r") as f:
    content = f.read()

if '-fpermissive' in content:
    print("Already patched")
else:
    old = """add_project_arguments(
  [
    '-Wno-unused-parameter',"""
    new = """add_project_arguments(
  [
    '-fpermissive',
    '-Wno-unused-parameter',"""
    content = content.replace(old, new)
    with open("/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/meson.build", "w") as f:
        f.write(content)
    print("Patched meson.build")
PYEOF
