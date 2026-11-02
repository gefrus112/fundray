#!/usr/bin/env bash
# Boot-test the Fundray Linux ISO in QEMU (serial console) and report PASS/FAIL.
# Proves: kernel boots, /init runs, the fundray CLI works, and 'fundray rebirth'
# reboots the machine cleanly.
set -uo pipefail

ISO="${1:-../artifacts/fundray-linux-1.0-x86_64.iso}"
LOG="${2:-serial-test.log}"

command -v qemu-system-x86_64 >/dev/null 2>&1 || {
  echo "qemu-system-x86_64 is not installed"; exit 2; }
[ -f "$ISO" ] || { echo "ISO not found: $ISO"; exit 2; }

{
  sleep 30
  printf 'uname -a\n';         sleep 3
  printf 'hostname\n';        sleep 2
  printf 'fundray info\n';    sleep 3
  printf 'fundray services\n'; sleep 2
  printf 'fundray clean\n';   sleep 2
  printf 'fundray bench\n';   sleep 5
  printf 'fundray rebirth\n'; sleep 12
} | timeout 180 qemu-system-x86_64 -m 512 -no-reboot -display none -monitor none \
    -serial stdio -cdrom "$ISO" > "$LOG" 2>&1
rc=$?

pass=1
check() { grep -q "$1" "$LOG" && echo "  ok   : $1" || { echo "  MISS : $1"; pass=0; }; }

echo "== boot log captured to: $LOG =="
check "6.12.115-fundray"
check "Fundray Linux 1.0"
check "0 services"
check "Page cache dropped"
check "Pushed 2000 MB"
check "Everything is clean. Rebooting"
if [ "$rc" -eq 0 ]; then
  echo "  ok   : qemu exited cleanly after 'fundray rebirth'"
else
  echo "  MISS : qemu did not exit cleanly (exit=$rc)"; pass=0
fi

if [ "$pass" -eq 1 ]; then echo "BOOT TEST: PASS"; exit 0
else echo "BOOT TEST: FAIL"; exit 1; fi
