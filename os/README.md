# Fundray Linux 1.0 "Rebirth"

**Fundray Linux is a real, bootable operating system** — a tiny live Linux
distribution assembled by the Fundray project from:

| Part | What | Size |
| --- | --- | --- |
| Kernel | official Linux 6.12.115 LTS, `tinyconfig` + `os/kernel.fragment` (`6.12.115-fundray`) | ~2.4 MB `bzImage` |
| Userland | static BusyBox 1.37.0, built from source | ~2.3 MB |
| Supervisor | `ctty` — a 30-line getty replacement (`os/ctty.c`) | ~700 KB static |
| Shell tools | `fundray` CLI (`os/initramfs/bin/fundray`) | ~4 KB |
| Everything | `artifacts/fundray-linux-1.0-x86_64.iso`, BIOS **and** UEFI boot | ~6.3 MB |

No services. No daemons. Nothing auto-starts, nothing phones home, and the whole
system runs live from RAM — no disk is ever mounted or touched.

## Try it (no install)

```sh
# in a VM
qemu-system-x86_64 -m 512 -cdrom artifacts/fundray-linux-1.0-x86_64.iso
# or add -nographic and use the serial console
```

Automated boot test (boots the ISO, drives the serial console, checks that
`fundray clean`, `fundray bench` and `fundray rebirth` work):

```sh
./qemu-test.sh
```

On real hardware: write the ISO to a USB stick (`dd if=... of=/dev/sdX bs=4M
status=progress` — double-check the device!) or use Ventoy. The ISO boots BIOS
(El Torito + isohybrid MBR) and UEFI (El Torito EFI entry).

## Build it from source

```sh
sudo apt-get install -y build-essential flex bison bc perl xz-utils curl \
  grub-pc-bin grub-efi-amd64-bin mtools xorriso
cd os && ./build.sh        # ~15-30 min: kernel + busybox + ISO
./qemu-test.sh             # prove the ISO you just built boots
```

`build.sh` downloads the sources from kernel.org and busybox.net, verifies the
kernel sha256, applies `os/kernel.fragment` on top of `make tinyconfig`, compiles
both, packs the initramfs with the kernel's own `gen_init_cpio` and assembles a
hybrid ISO with grub (`i386-pc-eltorito` + `x86_64-efi` images, isohybrid MBR).

## The fundray command line

| Command | What it does |
| --- | --- |
| `fundray about` | what this system is |
| `fundray info` | kernel, memory, uptime, processes |
| `fundray services` | prove that zero services are running |
| `fundray clean` | drop the page cache (frees RAM) |
| `fundray bench` | quick CPU throughput test |
| `fundray net` | DHCP on the wired NIC (drivers: e1000, e1000e, r8169, virtio-net) |
| `fundray rebirth` | the little reboot ceremony |
| `fundray license` | licensing (GPL-2.0) |

Kernel config is compiled in: `zcat /proc/config.gz | less`.

## Honest scope notes (v1)

- **Console only.** No desktop environment — this is a live rescue/tinker system.
- **Live only.** Nothing persists across reboots; nothing is installed.
- **Wired networking only.** Wi-Fi needs firmware that does not fit in a tiny
  kernel; `fundray net` works with the wired drivers listed above.
- **Tested in QEMU** (BIOS path, full boot + tool test). The UEFI path uses the
  standard GRUB EFI stub flow but has not been verified on real firmware yet.
- Fundray for **Windows remains a tweak toolkit**, not an operating system.
  Fundray Linux is a separate thing: an actual (very small) Linux distribution.

## License

Linux kernel: GPL-2.0. BusyBox: GPL-2.0+. The Fundray init, `fundray` CLI,
`ctty` and build kit: GPL-2.0. Sources are in this repository — build it
yourself and check.
