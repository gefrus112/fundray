#!/usr/bin/env bash
# ============================================================
#  Fundray Linux builder — one command, from source to ISO.
#
#  Builds a bootable x86_64 live ISO containing:
#    - the official Linux kernel (LTS), configured tiny
#    - a static BusyBox userland, built from source
#    - the fundray command line + ctty supervisor
#
#  Requirements (Debian/Ubuntu, installed with apt when missing):
#    build-essential flex bison bc perl xz-utils curl
#    grub-pc-bin grub-efi-amd64-bin mtools xorriso
#  Optional: qemu-system-x86 (for ./qemu-test.sh)
#
#  Usage:   ./build.sh
#  Result:  ../artifacts/fundray-linux-1.0-x86_64.iso
# ============================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
KVER="${KVER:-6.12.115}"
BBVER="${BBVER:-1.37.0}"
BUILD="${BUILD:-$HERE/build}"
JOBS="$(nproc)"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------- 1. dependencies ----------
if command -v apt-get >/dev/null 2>&1 && [ "${SKIP_APT:-0}" != 1 ]; then
  say "Installing build dependencies (needs sudo; SKIP_APT=1 to skip)"
  sudo apt-get update -qq || true
  sudo apt-get install -y build-essential flex bison bc perl xz-utils curl \
    grub-pc-bin grub-efi-amd64-bin mtools xorriso
fi
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1"; exit 1; }; }
need make; need gcc; need flex; need bison; need xz; need curl
need grub-mkimage; need mformat; need xorriso

mkdir -p "$BUILD" "$HERE/../artifacts"

# ---------- 2. kernel source ----------
say "Fetching Linux $KVER from kernel.org (sha256-verified)"
cd "$BUILD"
if [ ! -d "linux-$KVER" ]; then
  curl -fL -o "linux-$KVER.tar.xz" \
    "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KVER.tar.xz"
  curl -fsSL -o sha256sums.asc \
    "https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc" || true
  if [ -f sha256sums.asc ] && grep -q "linux-$KVER.tar.xz" sha256sums.asc; then
    sha256sum -c --ignore-missing sha256sums.asc
  fi
  tar -xf "linux-$KVER.tar.xz"
fi

# ---------- 3. configure + compile kernel ----------
say "Configuring kernel (tinyconfig + os/kernel.fragment)"
cd "linux-$KVER"
if [ ! -f .fundray-configured ]; then
  make tinyconfig
  ./scripts/kconfig/merge_config.sh -m .config "$HERE/kernel.fragment"
  make olddefconfig
  touch .fundray-configured
fi
say "Compiling the kernel ($JOBS jobs — this is the long step)"
make -j"$JOBS" bzImage
cp .config "$HERE/kernel.config.generated"

# ---------- 4. busybox from source ----------
say "Building static BusyBox $BBVER"
cd "$BUILD"
if [ ! -d "busybox-$BBVER" ]; then
  curl -fL -o "busybox-$BBVER.tar.bz2" \
    "https://busybox.net/downloads/busybox-$BBVER.tar.bz2"
  tar -xf "busybox-$BBVER.tar.bz2"
fi
cd "busybox-$BBVER"
if [ ! -f .fundray-configured ]; then
  make defconfig
  sed -i -e 's|^# CONFIG_STATIC is not set|CONFIG_STATIC=y|' \
         -e 's|^CONFIG_FEATURE_EDITING_ASK_TERMINAL=y|# CONFIG_FEATURE_EDITING_ASK_TERMINAL is not set|' \
         -e 's|^CONFIG_TC=y|# CONFIG_TC is not set|' .config
  make oldconfig >/dev/null
  touch .fundray-configured
fi
make -j"$JOBS"
BB="$BUILD/busybox-$BBVER/busybox"

# ---------- 5. ctty + initramfs ----------
say "Building ctty and packing the initramfs"
gcc -static -Os -o "$BUILD/ctty" "$HERE/ctty.c"
gcc "linux-$KVER/usr/gen_init_cpio.c" -o "$BUILD/gen_init_cpio"
sed -e "s|@BUSYBOX@|$BB|g" \
    -e "s|@CTTY@|$BUILD/ctty|g" \
    -e "s|@SRC@|$HERE/initramfs|g" \
    "$HERE/initramfs.cpio.in" > "$BUILD/cpio.list"
"$BUILD/gen_init_cpio" "$BUILD/cpio.list" | gzip -9 > "$BUILD/initramfs.gz"

# ---------- 6. GRUB images + ISO (BIOS + UEFI) ----------
say "Building GRUB boot images"
MOD="$(grub-mkimage --help >/dev/null 2>&1 && dirname "$(find /usr/lib/grub -maxdepth 1 -type d -name 'i386-pc' | head -n 1)")"
[ -d "$MOD/i386-pc" ] || MOD=/usr/lib/grub
MOD_EFI="$MOD/x86_64-efi"

pick() { local p="$1"; shift; for m in "$@"; do [ -f "$MOD/$p/$m.mod" ] && echo "$m"; done; }
BIOS_MODS="$(pick i386-pc biosdisk iso9660 cd boot linux normal configfile echo ls cat \
  test sleep halt reboot terminal terminfo font gfxterm all_video video_cirrus video_bochs \
  vga text search search_label search_fs_uuid search_fs_file part_msdos loopback gzio xzio)"
EFI_MODS="$(pick x86_64-efi iso9660 boot linux normal configfile echo ls cat test sleep \
  halt reboot terminal terminfo font gfxterm all_video search search_label search_fs_uuid \
  search_fs_file part_gpt part_msdos loopback gzio xzio)"

cat > "$BUILD/early.cfg" <<'EOCFG'
search --file --set=root --no-floppy /boot/grub/grub.cfg
set prefix=($root)/boot/grub
EOCFG

grub-mkimage -O i386-pc-eltorito -d "$MOD/i386-pc" -o "$BUILD/eltorito.img" \
  -c "$BUILD/early.cfg" -p '(cd0)/boot/grub' $BIOS_MODS
grub-mkimage -O x86_64-efi -d "$MOD_EFI" -o "$BUILD/bootx64.efi" \
  -c "$BUILD/early.cfg" -p '(cd0)/boot/grub' $EFI_MODS

rm -f "$BUILD/efi.img"
mformat -C -i "$BUILD/efi.img" -T 4096 -v FUNDRAY_EFI ::
mmd -i "$BUILD/efi.img" ::/EFI
mmd -i "$BUILD/efi.img" ::/EFI/BOOT
mcopy -i "$BUILD/efi.img" "$BUILD/bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI

say "Assembling the bootable ISO"
rm -rf "$BUILD/isodir"
mkdir -p "$BUILD/isodir/boot/grub/i386-pc"
cp "linux-$KVER/arch/x86/boot/bzImage" "$BUILD/isodir/boot/vmlinuz"
cp "$BUILD/initramfs.gz" "$BUILD/isodir/boot/initramfs.gz"
cp "$HERE/grub.cfg" "$BUILD/isodir/boot/grub/grub.cfg"
cp "$BUILD/eltorito.img" "$BUILD/isodir/boot/grub/i386-pc/eltorito.img"
cp "$BUILD/efi.img" "$BUILD/isodir/boot/grub/efi.img"
xorriso -as mkisofs -R -J -V FUNDRAYLINUX \
  -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
  -isohybrid-mbr "$MOD/i386-pc/boot_hybrid.img" \
  -partition_offset 16 \
  -o "$HERE/../artifacts/fundray-linux-1.0-x86_64.iso" "$BUILD/isodir"

say "Done: artifacts/fundray-linux-1.0-x86_64.iso"
echo "   boot test : ./qemu-test.sh"
echo "   real boot : write the ISO to a USB stick (dd) or boot it in any VM"
