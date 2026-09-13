#!/bin/bash
echo 177695 | sudo -S bash -c '
head -20 /tmp/build/Hyprland-0.30.0/CMakeLists.txt
echo "=== CMakeOutput ==="
cat /tmp/build/Hyprland-0.30.0/build/CMakeFiles/CMakeOutput.log 2>/dev/null | tail -20
echo "=== CMakeError ==="
cat /tmp/build/Hyprland-0.30.0/build/CMakeFiles/CMakeError.log 2>/dev/null | tail -30
'
