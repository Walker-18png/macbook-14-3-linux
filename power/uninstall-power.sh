#!/usr/bin/env bash
# Removes what install-power.sh added. Leaves EFI gpu-power-prefs on Intel;
# /root/gpu-power-prefs.bak holds the old value.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

systemctl disable gmux-igd.service gpu-prefs-guard.service dgpu-off.service smc-fans-auto.service 2>/dev/null
dkms remove tb-lc-keep/1.0 --all 2>/dev/null
rm -rf /usr/src/tb-lc-keep-1.0
dkms remove acpi-bridge-bus/1.0 --all 2>/dev/null
rm -rf /usr/src/acpi-bridge-bus-1.0
rm -f /usr/local/bin/{gmux-igd,gpu-prefs-guard,mac-wake-display,mac-hibernate,dgpu-off,dgpu-off-enable,dgpu-off-disable,smc-fans-auto} \
  /etc/systemd/system/{gmux-igd,gpu-prefs-guard,dgpu-off,smc-fans-auto}.service \
  /usr/lib/systemd/system-sleep/mac-sleep \
  /etc/systemd/sleep.conf.d/{s2idle,hibernate}.conf /etc/systemd/logind.conf.d/lid.conf \
  /etc/udev/rules.d/{61-gpu-names,62-t1-no-wakeup,63-tb-xhci-awake}.rules \
  /etc/modprobe.d/no-amdgpu.conf /etc/modules-load.d/tb-lc-keep.conf /etc/modules-load.d/acpi-bridge-bus.conf \
  /etc/dracut.conf.d/zz-no-gpu-in-initrd.conf /etc/issue.d/gpu-prefs.issue
# Take out only what the installer added, so later kernel-line edits survive.
[ -f /etc/kernel/cmdline ] && sed -i 's/ pcie_ports=native//' /etc/kernel/cmdline
command -v grubby >/dev/null && grubby --update-kernel=ALL --remove-args=pcie_ports=native
GRUB_REBUILD=0
if grep -q 'pcie_ports=native ' /etc/default/grub 2>/dev/null; then
  sed -i 's/pcie_ports=native //' /etc/default/grub
  GRUB_REBUILD=1
fi
systemctl daemon-reload
udevadm control --reload
if command -v reinstall-kernels >/dev/null; then reinstall-kernels
elif command -v mkinitcpio >/dev/null; then mkinitcpio -P
elif command -v dracut >/dev/null; then dracut --regenerate-all --force
elif command -v update-initramfs >/dev/null; then update-initramfs -u -k all
fi
if [ $GRUB_REBUILD = 1 ]; then
  if command -v update-grub >/dev/null; then update-grub
  elif command -v grub2-mkconfig >/dev/null; then grub2-mkconfig -o /boot/grub2/grub.cfg
  else grub-mkconfig -o /boot/grub/grub.cfg
  fi
fi
echo "Removed. Reboot to finish."
