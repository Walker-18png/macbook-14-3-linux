#!/usr/bin/env bash
# Removes what install-power.sh added. Leaves EFI gpu-power-prefs on Intel;
# /root/gpu-power-prefs.bak holds the old value.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

systemctl disable gmux-igd.service gpu-prefs-guard.service dgpu-off.service 2>/dev/null
dkms remove tb-lc-keep/1.0 --all 2>/dev/null
rm -rf /usr/src/tb-lc-keep-1.0
rm -f /usr/local/bin/{gmux-igd,gpu-prefs-guard,mac-wake-display,dgpu-off,dgpu-off-enable,dgpu-off-disable} \
  /etc/systemd/system/{gmux-igd,gpu-prefs-guard,dgpu-off}.service \
  /usr/lib/systemd/system-sleep/mac-sleep \
  /etc/systemd/sleep.conf.d/s2idle.conf /etc/systemd/logind.conf.d/lid.conf \
  /etc/udev/rules.d/{61-gpu-names,62-t1-no-wakeup,63-tb-xhci-awake}.rules \
  /etc/modprobe.d/no-amdgpu.conf /etc/modules-load.d/tb-lc-keep.conf \
  /etc/dracut.conf.d/zz-no-gpu-in-initrd.conf /etc/issue.d/gpu-prefs.issue
[ -f /etc/kernel/cmdline.bak-power ] && mv /etc/kernel/cmdline.bak-power /etc/kernel/cmdline
systemctl daemon-reload
udevadm control --reload
if command -v reinstall-kernels >/dev/null; then reinstall-kernels
elif command -v mkinitcpio >/dev/null; then mkinitcpio -P
elif command -v dracut >/dev/null; then dracut --regenerate-all --force
fi
echo "Removed. Reboot to finish."
