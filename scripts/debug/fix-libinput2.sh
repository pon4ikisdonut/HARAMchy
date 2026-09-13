#!/bin/bash
python3 << 'PYEOF'
with open("/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/meson.build", "r") as f:
    content = f.read()

if 'HAVE_LIBINPUT_CUSTOM_ACCEL' not in content:
    # Add after the libinput dependency
    marker = "dependency('libinput',"
    idx = content.find(marker)
    if idx >= 0:
        # Find the end of this dependency call
        depth = 0
        for i in range(idx, len(content)):
            if content[i] == '(':
                depth += 1
            elif content[i] == ')':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        # Insert version check after the dependency
        insert = "\nif libinput.version().version_compare('>=1.24')\n\tadd_project_arguments('-DHAVE_LIBINPUT_CUSTOM_ACCEL', language: ['cpp', 'c'])\nendif"
        content = content[:end] + insert + content[end:]
        with open("/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/meson.build", "w") as f:
            f.write(content)
        print("Patched meson.build")
    else:
        print("Could not find libinput dependency")
else:
    print("Already patched")
PYEOF
