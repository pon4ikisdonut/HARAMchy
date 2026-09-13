# Testing HARAMchy ISO

## Prerequisites

- QEMU (recommended) or VMware Workstation/Fusion
- HARAMchy ISO file (`haramchy-*.iso`)
- At least 4GB RAM allocated to VM
- 20GB+ disk space for VM

---

## QEMU Testing

### Basic Boot Test

```bash
# BIOS boot (simplest)
qemu-system-x86_64 \
  -cdrom haramchy-*.iso \
  -m 4G \
  -enable-kvm \
  -vga virtio \
  -display gtk

# Or without KVM (slower, for non-Linux hosts)
qemu-system-x86_64 \
  -cdrom haramchy-*.iso \
  -m 4G \
  -vga virtio \
  -display gtk
```

### EFI Boot Test

```bash
# Create EFI variable store
qemu-img create -f qcow2 efi-vars.fd 64M

# Download OVMF firmware (if not bundled)
# https://github.com/tianocore/edk2/releases

qemu-system-x86_64 \
  -cdrom haramchy-*.iso \
  -m 4G \
  -enable-kvm \
  -bios /usr/share/edk2/x64/OVMF.fd \
  -drive if=pflash,format=raw,file=efi-vars.fd \
  -vga virtio \
  -display gtk
```

### Install to Disk (Full Test)

```bash
# Create virtual disk
qemu-img create -f qcow2 haramchy-disk.qcow2 20G

# Boot ISO with disk
qemu-system-x86_64 \
  -cdrom haramchy-*.iso \
  -hda haramchy-disk.qcow2 \
  -m 4G \
  -enable-kvm \
  -vga virtio \
  -display gtk
```

### Network Test

```bash
# Enable network (NAT)
qemu-system-x86_64 \
  -cdrom haramchy-*.iso \
  -m 4G \
  -enable-kvm \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -vga virtio \
  -display gtk
```

---

## VMware Testing

### Create New VM

1. File > New Virtual Machine
2. Custom (Advanced)
3. Guest OS: Linux > Other Linux 5.x or later 64-bit
4. RAM: 4096 MB
5. Disk: 20 GB, single file
6. CD/DVD: ISO image (`haramchy-*.iso`)
7. Network: NAT

### VMX Configuration

Add to `.vmx` file for best performance:

```
vhv.enable = "TRUE"
vcpu.hotadd = "TRUE"
memsize = "4096"
disk.EnableUUID = "TRUE"
```

### EFI Boot in VMware

1. VM > Settings > Options > Advanced > Firmware Type
2. Select "UEFI"
3. Add EFI variable store if needed

---

## Expected Boot Behavior

### BIOS Boot
1. GRUB menu appears with "HARAMchy" entry
2. Kernel loads, systemd starts
3. Login prompt (TTY or SDDM/Greetd)

### EFI Boot
1. GRUB menu (may show "Install" and "Boot" options)
2. Same as BIOS after kernel load

### First Boot
1. If installed to disk: systemd boots to multi-user or graphical target
2. If live ISO: starts live session with auto-login

---

## Testing Checklist

### Boot
- [ ] BIOS boot works
- [ ] EFI boot works
- [ ] GRUB menu displays correctly
- [ ] Kernel loads without errors
- [ ] systemd services start

### haramd
- [ ] haramd daemon starts on boot
- [ ] Process monitoring active
- [ ] Prayer time calculation works
- [ ] Siren sounds on haram violation

### Desktop
- [ ] Hyprland session available
- [ ] Waybar appears
- [ ] Alacritty launches
- [ ] Mouse/keyboard work (libinput)

### Package Manager
- [ ] `hrm search` works
- [ ] `hrm install` downloads and installs
- [ ] `hrm verify` checks integrity
- [ ] haram detection blocks bad packages

### Network
- [ ] Network connectivity (if enabled)
- [ ] Firewall rules active
- [ ] Prayer-time network blocking works

---

## Troubleshooting

### Boot Fails
- Check QEMU: add `-serial stdio` to see kernel messages
- Try `-append "console=ttyS0"` for serial console
- Verify ISO integrity: `sha256sum haramchy-*.iso`

### No Display
- Try different VGA: `-vga std`, `-vga cirrus`, `-vga none`
- Check Hyprland logs: `~/.cache/hyprland/hyprland.log`
- Switch to TTY: Ctrl+Alt+F2

### haramd Not Starting
- Check systemd: `systemctl status haramd`
- Check logs: `journalctl -u haramd`
- Manual start: `/usr/lib/haramd/haramd -c /etc/haramd/config.toml`

### Network Issues
- Check firewall: `iptables -L -n`
- Check NetworkManager: `systemctl status NetworkManager`
- Verify interface: `ip link show`

---

## Performance Notes

- QEMU with `-enable-kvm` is essential for acceptable performance
- Without KVM, expect 5-10x slowdown
- VMware generally faster than QEMU without KVM
- Allocate at least 2 CPU cores for smooth desktop experience
