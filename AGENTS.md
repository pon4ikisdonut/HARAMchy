# HARAMchy Project - AI Agent Context

## Project Overview

**HARAMchy** — custom Linux distribution built from scratch (LFS-style) with Hyprland desktop, custom kernel with haram_guard LSM module, security daemon, and custom package manager.

**Repository:** https://github.com/pon4ikisdonut/HARAMchy
**Packages repo:** https://github.com/kyrosystems/haramchy-packages

## Environment

- **Host:** Windows + WSL2 (Ubuntu-22.04)
- **WSL user:** `pon4ikisdonut`
- **LFS user:** `lfs` (home: `/home/lfs/`)
- **LFS root:** `/home/lfs/lfs-root/`
- **LFS target:** `x86_64-lfs-linux-gnu`
- **Toolchain:** `/home/lfs/lfs-root/tools/bin/`
- **Source tarballs:** `/home/lfs/src/` (85+ tarballs)
- **WSL commands:** `wsl -e bash -lc "..."` or write `.sh` scripts to `/mnt/c/Users/pon4ikisdonut/AppData/Local/Temp/opencode/` and run with `sudo -S bash`
- **PowerShell:** Cannot use `&&`, `()`, pipes with `$()` in single-quoted sudo blocks. Use script files.
- **PowerShell quoting:** Breaks `sudo -S bash -c '...'` when comments contain `()` — avoid complex quoting in single-quoted sudo blocks

## Key Build Facts

- **GCC:** 13.4.0 (from `ubuntu-toolchain-r/test` PPA) — `<format>` header needs GCC 13+
- **glibc:** 2.35 (Ubuntu 22.04 host), LFS headers were glibc 2.38 — caused `__isoc23_strtol` and `struct ip_mreqn` errors. Fixed by replacing chroot headers with host glibc 2.35 headers
- **Build approach:** Chroot uses host GCC 13 + host glibc 2.35 runtime, NOT LFS-compiled GCC/glibc. All shared libs copied from `/lib/x86_64-linux-gnu/` on host
- **`/sources` mount:** Must `mount --bind /home/lfs/src "$LFS/sources"` BEFORE chroot build calls
- **pkg-config version faking:** Host `.pc` files show old versions. Must `sed -i "s/^Version:.*/Version: X.Y.Z/"` all `.pc` files to prevent build failures
- **Library path mismatch:** Meson builds install to `/usr/lib64/` but linker searches `/usr/lib/x86_64-linux-gnu/`. Manually copy `.so` files after each meson build
- **`reboot()` API:** On glibc 2.35: `reboot(LINUX_REBOOT_CMD_RESTART)` — 1 arg, not 3-arg BSD form

## Completed Build Stages

### Toolchain + LFS Stages 1-8 ✅
- GCC Pass 1 + Binutils Pass 1 via `build-toolchain-v2.sh`
- All markers at `/home/lfs/.build-markers/`
- Chapter 6: ALL 30/30 Temp Tools
- Chapter 8: shadow-4.14.5, sysvinit-3.07, procps-ng-4.0.3

### Kernel ✅
- Version: 6.6
- Built with `CONFIG_HARAM_GUARD=y`
- Output: `/home/lfs/lfs-root/boot/vmlinuz-6.6`, `System.map-6.6`, `config-6.6`
- haram_guard module: `E:\projects\haramchy\kernel-src\haram_guard.c` (~1068 lines)

### Wayland/Hyprland Stack ✅ (ALL 9 packages)
- wayland 1.22.0, wayland-protocols 1.32, libinput, libdisplay-info, libliftoff, libxkbcommon, pixman, udis86, seatd, wlroots 0.17.0-dev
- wlroots commit: `98a745d926d8048bc30aef11b421df207a01c279`

### Chroot Infrastructure ✅
- cmake, ninja, meson, python3, g++-13, git, wayland-scanner, bison, flex, m4, xwayland
- All xcb headers (xcb_ewmh.h, xcb_icccm.h, etc.)
- xwayland stub pkg-config at `/usr/lib/x86_64-linux-gnu/pkgconfig/xwayland.pc`

### Hyprland 0.30.0 ✅ (COMPILED + LINKED)
- All 418 C++ files compiled with g++-13 + `-fpermissive`
- Linked with `libdrm_stubs.so` for missing DRM symbols
- Binary: `/home/lfs/lfs-root/usr/bin/Hyprland` (5.5MB ELF)
- hyprctl: `/home/lfs/lfs-root/usr/bin/hyprctl`
- Default config: `/home/lfs/lfs-root/usr/share/hyprland/hyprland.conf`
- DRM stubs source: `E:\projects\haramchy\drm_stubs.c`
- DRM stubs library: `/usr/lib/x86_64-linux-gnu/libdrm_stubs.so` (also in chroot at `/home/lfs/lfs-root/usr/lib/libdrm_stubs.so`)
- build.ninja patched to include `-ldrm_stubs` before `-ldrm`

### haramd v3.0 ✅ (COMPILED + TESTED)
- Source: `E:\projects\haramchy\haram-rules\haramd.c` + `haramd.h`
- 18 builtin rules, 77 regex compiled
- Features: Keyboard (evdev), screen (fb0), USB (inotify), DPI (/proc/net/tcp), panic engine (SysRq/reboot), iptables blocklist
- Blocklists: `blocklists/microsoft_domains.txt` (50+), `blocklists/microsoft_ips.txt`
- Windows detection: 14+ English/Russian variants including bill.gates
- Quran rules: pork, alcohol, gambling, drugs, violence, immoral content, deception, occult, riba/usury, prayer enforcement
- Tested running: `Loaded 18 builtin rules, Compiled 77 regex`, all monitors active

### hrm v0.2.0 ✅ (COMPILED)
- Source: `E:\projects\haramchy\haram-rules\hrm.c` (~2060 lines)
- JSON manifest support per `repodocs/MANIFEST_SPEC.md`
- Repo management: `hrm repo add/remove/list/sync`
- SHA-256 verified downloads via curl
- Install types: tarball, RPM, AppImage
- Haram detection on package name + tags
- Post-install script support
- Local .hrm fallback support
- Compiles clean with `gcc -Wall -Wextra -std=c11`

### os-release ✅
```
NAME="HARAMchy"
VERSION="1.0"
ID=haramchy
ID_LIKE=haramchy
PRETTY_NAME="HARAMchy Linux"
```

### GRUB ✅
- BIOS modules: `/home/lfs/lfs-root/usr/lib/grub/i386-pc/` (275 modules)
- EFI modules: `/home/lfs/lfs-root/usr/lib/grub/x86_64-efi/` (266 modules)
- `configfile` not `config` (GRUB module name)

### Busybox ✅
- `/home/lfs/lfs-root/bin/busybox` (v1.30.1, static)
- Symlinks in `/bin/`: sh, ls, cp, mv, mkdir, mount, umount, switch_root, etc.

## ISO Build

### Current ISO: `haramchy-1.0-1.iso` (1.2GB)
- Location: `E:\haramchy\iso\haramchy-1.0-1.iso`
- SHA256: `50b34e9d2c4e66549546f8fd5ea7745df26324010000f171a9c08a0158fdf563`
- Label: `HARAMCHY`
- Format: xorriso, BIOS + EFI dual boot

### ISO Build Process
1. Rebuild initramfs with busybox + init.sh + kernel modules
2. Create squashfs of chroot (gzip, ~1.2GB from 5.3GB)
3. Create GRUB BIOS image (i386-pc, `configfile` not `config`)
4. Create GRUB EFI image (x86_64-efi)
5. xorriso with `-eltorito-boot boot/bios.img` and `-eltorito-alt-boot -e boot/efiboot.img`
6. Boot images must be inside the stage tree for xorriso to find them

### Build Script
```bash
wsl -e bash -lc "echo '177695' | sudo -S bash /path/to/rebuild-all-v2.sh"
```

### Key Files
- `E:\projects\haramchy\iso\build-iso.sh` — ISO build script
- `E:\projects\haramchy\iso\grub.cfg` — GRUB config (uses `search --set=root --label HARAMCHY`)
- `E:\projects\haramchy\iso\init.sh` — Live boot init (mounts ISO, squashfs, overlay, switch_root)

## Known Issues / TODO

### ISO Boot Problem
When booting from ISO: just a blinking cursor `_` and nothing happens.
Possible causes being investigated:
1. init.sh may not be found by kernel
2. squashfs mount may fail silently
3. overlay setup may fail
4. `switch_root` may not work with busybox 1.30.1
5. Kernel may not support some needed feature

**Debug approach:** Try "Recovery Shell" GRUB entry (`init=/bin/sh`) — if that works, it's an init issue. If not, it's a kernel/GRUB issue.

### Potential Fixes to Try
1. Test `init=/bin/sh` GRUB entry — bypasses init entirely
2. Add `panic=1` to kernel cmdline — auto-reboot on kernel panic
3. Add `earlyprintk=vga` or `earlycon=ttyS0` for early boot messages
4. Check if the issue is with BIOS boot vs EFI boot (try UEFI in VM)
5. Try writing ISO to USB and booting from real hardware
6. The busybox `switch_root` may need `/dev` nodes — ensure `cp -a /dev/* /mnt/root/dev/` works
7. May need to build a custom busybox with more features enabled
8. May need to use `kexec` or direct kernel loading instead of GRUB

### Remaining Tasks
- Fix ISO boot issue
- Test on real hardware
- Create install script for permanent installation
- Configure haramd to run at boot
- Configure Hyprland autostart
- Set up hrm package repos

## Manifest Spec (for hrm)
- JSON manifests at `manifests/<category>/<package-name>/<version>.json`
- Required: schema_version, name, version, release, category, summary, license, url, sha256, size_bytes, architecture, dependencies, install_type, maintainer, homepage, source_url
- Optional: description, tags, conflicts, provides, replaces, post_install_script, post_install_script_sha256
- Install types: rpm, tarball, appimage, flatpak

## Git History
```
6b15d86 HARAMchy v1.0: complete bootable Linux distribution
a7cf5ba Fix init: bash->sh, show kernel messages, debug shell entry
01ba2c8 Fix live boot: proper init with overlay, squashfs mount, search-based GRUB, build numbering
```
