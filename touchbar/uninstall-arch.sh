#!/usr/bin/env bash
# Removes the T1 Touch Bar driver installed by install-arch.sh.
#   sudo ./uninstall-arch.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

modprobe -r apple_touchbar 2>/dev/null || true
modprobe -r apple_ibridge 2>/dev/null || true
dkms remove -m apple-ib-drv -v 0.1 --all 2>/dev/null || true
rm -rf /usr/src/apple-ib-drv-0.1
rm -f /etc/modprobe.d/apple-touchbar.conf /etc/modprobe.d/blacklist-appletbdrm.conf \
      /etc/udev/rules.d/99-ibridge.rules \
      /etc/modules-load.d/apple-touchbar.conf
udevadm control --reload
depmod -a

echo "Removed. Reboot to return the iBridge to its default state: sudo reboot"
