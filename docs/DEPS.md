# HARAMchy Dependencies

## Toolchain (Stage 1)

| Package | Version | Source |
|---------|---------|--------|
| GCC | 13.2.0 | https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/ |
| Binutils | 2.42 | https://ftp.gnu.org/gnu/binutils/ |
| Glibc | 2.38 | https://ftp.gnu.org/gnu/glibc/ |
| Linux API Headers | 6.6 | https://cdn.kernel.org/pub/linux/kernel/v6.x/ |
| MPC | 1.3.1 | https://ftp.gnu.org/gnu/mpc/ |
| MPFR | 4.2.1 | https://ftp.gnu.org/gnu/mpfr/ |
| GMP | 6.3.0 | https://ftp.gnu.org/gnu/gmp/ |
| ISL | 0.26 | https://libisl.sourceforge.io/ |

## Temporary Tools (Stage 1)

| Package | Version | Source |
|---------|---------|--------|
| M4 | 1.4.19 | https://ftp.gnu.org/gnu/m4/ |
| Ncurses | 6.4 | https://ftp.gnu.org/gnu/ncurses/ |
| Bash | 5.2.21 | https://ftp.gnu.org/gnu/bash/ |
| Coreutils | 9.4 | https://ftp.gnu.org/gnu/coreutils/ |
| Diffutils | 3.10 | https://ftp.gnu.org/gnu/diffutils/ |
| File | 5.45 | https://astron.com/pub/file/ |
| Findutils | 4.9.0 | https://ftp.gnu.org/gnu/findutils/ |
| Gawk | 5.3.0 | https://ftp.gnu.org/gnu/gawk/ |
| Grep | 3.11 | https://ftp.gnu.org/gnu/grep/ |
| Sed | 4.9 | https://ftp.gnu.org/gnu/sed/ |
| Bison | 3.8.2 | https://ftp.gnu.org/gnu/bison/ |
| Perl | 5.38.0 | https://www.cpan.org/src/ |
| Python | 3.11.6 | https://www.python.org/ftp/release/ |
| Util-linux | 2.39 | https://www.kernel.org/pub/linux/utils/util-linux/ |
| Texinfo | 7.1 | https://ftp.gnu.org/gnu/texinfo/ |
| Gettext | 0.22.4 | https://ftp.gnu.org/gnu/gettext/ |
| Bison | 3.8.2 | https://ftp.gnu.org/gnu/bison/ |
| Make | 4.3 | https://ftp.gnu.org/gnu/make/ |

## Kernel (Stage 2)

| Package | Version | Source |
|---------|---------|--------|
| Linux | 6.6 LTS | https://cdn.kernel.org/pub/linux/kernel/v6.x/ |

## Core System (Stage 1 Final)

| Package | Version | Source |
|---------|---------|--------|
| Systemd | 255 | https://github.com/systemd/systemd |
| Util-linux | 2.39 | https://www.kernel.org/pub/linux/utils/util-linux/ |
| D-Bus | 1.14.x | https://dbus.freedesktop.org/releases/ |
| Elogind | 255.x (compat) | https://github.com/elogind/elogind |
| Kmod | 31 | https://www.kernel.org/pub/linux/utils/kernel/kmod/ |
| Iana-etc | 20231117 | https://www.iana.org/time-zones |
| Perl | 5.38.0 | https://www.cpan.org/src/ |

## Desktop Environment (Stage 4)

| Package | Version | Source |
|---------|---------|--------|
| Wayland | latest stable (1.22+) | https://gitlab.freedesktop.org/wayland/wayland |
| wlroots | latest stable (0.17+) | https://gitlab.freedesktop.org/wlroots/wlroots |
| Hyprland | latest stable | https://github.com/hyprwm/Hyprland |
| xdg-desktop-portal-hyprland | latest stable | https://github.com/hyprwm/xdg-desktop-portal-hyprland |
| Waybar | latest stable | https://github.com/Alexays/Waybar |
| Alacritty | latest stable | https://github.com/alacritty/alacritty |
| libinput | 1.24+ | https://gitlab.freedesktop.org/libinput/libinput |
| libxkbcommon | 1.5+ | https://github.com/xkbcommon/libxkbcommon |
| xwayland | latest stable | https://gitlab.freedesktop.org/xorg/proto/xwayland |
| Polkit | latest stable | https://gitlab.freedesktop.org/polkit/polkit |
| Seatd | latest stable | https://git.sr.ht/~kennylevinsen/seatd |

## Package Manager (Stage 5)

| Component | Implementation |
|-----------|----------------|
| hrm | Standalone C, no external deps |
| SHA-256 | Inline implementation (no OpenSSL) |
| Archive handling | tar.gz via libarchive or system tar |
| Manifest | TOML parser (embedded or minimal deps) |

## ISO Builder (Stage 6)

| Package | Version | Source |
|---------|---------|--------|
| GRUB | 2.12+ | https://ftp.gnu.org/gnu/grub/ |
| xorriso | 1.5.6+ | https://www.gnu.org/software/xorriso/ |
| Mtools | latest | https://ftp.gnu.org/gnu/mtools/ |
| EFI Shell | latest | https://github.com/tianocore/edk2 |
