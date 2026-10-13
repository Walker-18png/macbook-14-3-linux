#!/usr/bin/env bash
#
# Arch Linux installer for the T1 (2016-2017 MacBook Pro) Touch Bar.
# Port of AJ-dev-i60/t1-touchbar install.sh. The original is apt-only; this does
# the same steps with pacman and kernel headers from the running kernel.
#
#   sudo ./install-arch.sh [--dry-run]
#
set -euo pipefail

DKMS_NAME=apple-ib-drv
DKMS_VER=0.1
REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="/usr/src/${DKMS_NAME}-${DKMS_VER}"
DRY=0

for a in "$@"; do case "$a" in
  --dry-run) DRY=1;;
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  *) echo "unknown option: $a" >&2; exit 2;;
esac; done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
run() { printf '   + %s\n' "$*"; [ "$DRY" = 1 ] || "$@"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
command -v pacman >/dev/null || { echo "This installer is for Arch Linux (pacman)." >&2; exit 1; }

if ! lsusb 2>/dev/null | grep -qi '05ac:8600'; then
  echo "No iBridge (05ac:8600) on USB. This is for 2016-2017 MacBook Pro (T1) models." >&2
  exit 1
fi
say "T1 iBridge (05ac:8600) found."

# The driver and the old guide's modules both claim the iBridge. Remove the older
# DKMS module and its load options so only one driver owns the device.
say "Removing older iBridge modules, if present."
if dkms status 2>/dev/null | grep -q '^appleibridge/'; then
  run dkms remove -m appleibridge -v 0.1 --all || true
fi
[ -f /etc/modprobe.d/apple-ib-tb.conf ] && run rm -f /etc/modprobe.d/apple-ib-tb.conf
for m in apple_ib_tb apple_ibridge apple_touchbar; do
  lsmod | grep -q "^${m} " && run modprobe -r "$m" || true
done

say "Installing kernel headers and DKMS."
run pacman -S --needed --noconfirm dkms "linux-headers" || true
if [ ! -d "/usr/lib/modules/$(uname -r)/build" ]; then
  echo "Kernel headers for $(uname -r) are missing. Install the headers package that matches your kernel, then re-run." >&2
  exit 1
fi

say "Copying driver source to ${SRC}."
run install -d "$SRC"
run cp "$REPO"/apple-ib-drv/{Makefile,apple-ibridge.c,apple-ibridge.h,apple-touchbar.c,hid-ids.h,dkms.conf} "$SRC"/

say "Building and installing with DKMS."
if dkms status "${DKMS_NAME}/${DKMS_VER}" 2>/dev/null | grep -q installed; then
  say "  ${DKMS_NAME}/${DKMS_VER} is already installed."
else
  run dkms add -m "$DKMS_NAME" -v "$DKMS_VER" || true
  run dkms build -m "$DKMS_NAME" -v "$DKMS_VER"
  run dkms install -m "$DKMS_NAME" -v "$DKMS_VER"
fi
run depmod -a

say "Writing configs. skip_acpi_power=1 comes first: without it the module runs ASOC.SOCW(1) and freezes a T1 at load."
run install -m644 "$REPO/apple-ib-drv/packaging/apple-touchbar.modprobe.conf" /etc/modprobe.d/apple-touchbar.conf
run install -m644 "$REPO/apple-ib-drv/packaging/99-ibridge.rules" /etc/udev/rules.d/99-ibridge.rules
run install -m644 "$REPO/apple-ib-drv/packaging/apple-touchbar.modules-load.conf" /etc/modules-load.d/apple-touchbar.conf
run udevadm control --reload
run udevadm trigger

say "Loading the driver now."
run modprobe apple_ibridge skip_acpi_power=1 || say "  Could not load live. A reboot will load it."

echo
say "Self-check"
if [ "$DRY" = 0 ]; then
  lsmod | grep -q '^apple_touchbar' && echo "   ok  apple_touchbar loaded" || echo "   --  apple_touchbar not loaded yet"
  dmesg 2>/dev/null | grep -qi 'skip_acpi_power.*NOT running' && echo "   ok  freeze guard active" || echo "   --  freeze guard message not in dmesg"
  dmesg 2>/dev/null | grep -qi 'apple-touchbar.*input' && echo "   ok  Touch Bar input created" || echo "   --  no Touch Bar input yet"
fi
echo
say "Done. Reboot to finish, so the driver claims the iBridge at boot:  sudo reboot"
echo "   If the bar stays dark after reboot, see the Troubleshooting section of README.md."
