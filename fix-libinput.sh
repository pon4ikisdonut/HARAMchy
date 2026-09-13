#!/bin/bash
python3 << 'PYEOF'
with open("/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/src/managers/input/InputManager.cpp", "r") as f:
    content = f.read()

# Clean previous patches
for patch in ['#ifdef HAVE_LIBINPUT_CUSTOM_ACCEL\n', '#if LIBINPUT_VERSION_MINORMAJOR >= 12400\n', '\n#endif\n                    } catch']:
    content = content.replace(patch, 'NOOP')

old = """                    const auto CONFIG = libinput_config_accel_create(LIBINPUT_CONFIG_ACCEL_PROFILE_CUSTOM);
                    libinput_config_accel_set_points(CONFIG, LIBINPUT_ACCEL_TYPE_MOTION, step, points.size(), points.data());
                    libinput_device_config_accel_set_profile(LIBINPUTDEV, LIBINPUT_CONFIG_ACCEL_PROFILE_CUSTOM);
                    libinput_config_accel_destroy(CONFIG);"""

new = """#ifdef HAVE_LIBINPUT_CUSTOM_ACCEL
                    const auto CONFIG = libinput_config_accel_create(LIBINPUT_CONFIG_ACCEL_PROFILE_CUSTOM);
                    libinput_config_accel_set_points(CONFIG, LIBINPUT_ACCEL_TYPE_MOTION, step, points.size(), points.data());
                    libinput_device_config_accel_set_profile(LIBINPUTDEV, LIBINPUT_CONFIG_ACCEL_PROFILE_CUSTOM);
                    libinput_config_accel_destroy(CONFIG);
#endif"""

content = content.replace(old, new)

with open("/home/lfs/lfs-root/tmp/build/Hyprland-0.30.0/src/managers/input/InputManager.cpp", "w") as f:
    f.write(content)
print("Done: InputManager.cpp")
PYEOF

# Just add the flag directly in the build command
echo "Patched files."
