#!/bin/bash
echo "=== Modules installed ==="
find /home/lfs/lfs-root/lib/modules/6.6.0 -name "*.ko" 2>/dev/null | head -20
echo "=== Security modules ==="
ls /home/lfs/lfs-root/lib/modules/6.6.0/kernel/security/ 2>/dev/null
echo "=== haram_guard ==="
find /home/lfs/lfs-root/lib/modules/6.6.0 -name "haram_guard*" 2>/dev/null
echo "=== Boot ==="
ls /home/lfs/lfs-root/boot/ 2>/dev/null
echo "=== haram-siren ==="
ls /home/lfs/lfs-root/usr/bin/haram-siren 2>/dev/null || echo "not found"
