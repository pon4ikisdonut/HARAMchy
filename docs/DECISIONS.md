# Technical Decisions & Deviations from Plan

## Toolchain Build

### GCC Pass 1: `--disable-libstdc++-v3`
GCC 13.2.0 Pass 1 requires `--disable-libstdc++-v3` flag. Without it the build fails because the target C library (glibc) is not yet available and libstdc++ cannot link against it. This is an LFS book requirement that was initially missed, causing a full rebuild of the toolchain.

### libbacktrace Non-Fatal Install Error
During GCC Pass 1 the libbacktrace library produces an install error. This is non-fatal and expected:
- The target-arch libbacktrace cannot build without glibc (not yet installed)
- The host-arch libbacktrace is built and works correctly
- The error can be safely ignored; GCC continues building without issue

## haramd Daemon

### C, Not Rust
haramd is implemented in C per the original prompt requirements. While Rust would offer memory safety guarantees, the daemon needs tight integration with Linux kernel interfaces (pty, inotify, netlink sockets, /proc parsing) where C provides direct, idiomatic access without FFI overhead.

### Process Monitoring Approach
haramd uses three complementary monitoring mechanisms:
- **pty monitoring**: Traps command execution via pseudo-terminal logging
- **inotify**: Watches filesystem paths for haram file access
- **netlink**: Receives kernel events from haram_guard module

## haram-siren

### PC Speaker Fallback
haram-siren uses the kernel `KIOCSOUND` ioctl for PC speaker output when `aplay` is unavailable. This ensures the alarm works on minimal systems without ALSA/sound drivers installed. The framebuffer countdown is primary; PC speaker is a fallback for headless or driver-less environments.

## Package Manager (hrm)

### Standalone SHA-256 Implementation
hrm implements SHA-256 from scratch rather than linking against OpenSSL or similar. This keeps the package manager dependency-free and suitable for use during early boot or in minimal environments where crypto libraries may not be installed.

## Prayer Time Calculation

### Astronomical Formulas, No Internet
Prayer times are computed using standard astronomical formulas (sun position calculations based on latitude, longitude, and date). No internet connection is required. The calculations support all five daily prayers plus Jumu'ah. Configurable via `config.toml`.

## Content Detection

### Heuristic Mode: Face Detection Stub
In heuristic mode, idol/portrait detection uses file header analysis and metadata inspection rather than full OpenCV-based face detection. OpenCV is not bundled to keep the system minimal. The stub analyzes EXIF data, file dimensions, and header signatures as a lightweight proxy. This is a known limitation; full ML-based detection is planned for a future release.
