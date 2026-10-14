#!/usr/bin/env bash
#
# Sleep and hybrid graphics on the MacBookPro14,3 (Intel HD 630 + Radeon Pro 450/455/460).
#   sudo ./install-power.sh              Intel drives the panel, lid sleep (s2idle) works
#   sudo ./install-power.sh --dgpu-off   also power the Radeon off at boot (saves about 10 W)
#   sudo ./install-power.sh --dry-run    print the steps only
#
set -euo pipefail

DRY=0 DGPU=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --dgpu-off) DGPU=1 ;;
    *) echo "usage: sudo $0 [--dgpu-off] [--dry-run]" >&2; exit 2 ;;
  esac
done
[ $DRY = 1 ] || [ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")" && pwd)"
run() { echo "+ $*"; [ $DRY = 1 ] || "$@"; }
put() { run install -Dm"$1" "$REPO/$2" "$3"; }

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [ "$model" != MacBookPro14,3 ]; then
  echo "This is '$model', not a MacBookPro14,3. The gmux, PCI and ACPI paths here are for the 14,3." >&2
  exit 1
fi

echo "== 1. Firmware: boot with the Intel GPU on the panel (EFI gpu-power-prefs)"
V=/sys/firmware/efi/efivars/gpu-power-prefs-fa4ce28d-b62f-4c99-9cc3-6815686e30f9
if [ -e "$V" ] && [ ! -e /root/gpu-power-prefs.bak ]; then run cp "$V" /root/gpu-power-prefs.bak; fi
put 755 bin/gpu-prefs-guard /usr/local/bin/gpu-prefs-guard
run /usr/local/bin/gpu-prefs-guard
run rm -f /etc/issue.d/gpu-prefs.issue

echo "== 2. GPU boot order: Intel probes first and owns eDP-1"
put 644 conf/no-amdgpu.conf /etc/modprobe.d/no-amdgpu.conf
put 644 udev/61-gpu-names.rules /etc/udev/rules.d/61-gpu-names.rules
put 755 bin/gmux-igd /usr/local/bin/gmux-igd
put 644 systemd/gmux-igd.service /etc/systemd/system/gmux-igd.service
put 644 systemd/gpu-prefs-guard.service /etc/systemd/system/gpu-prefs-guard.service
# gmux-igd has to switch the panel before i915 loads, so keep both GPU drivers out of the initrd.
if command -v dracut >/dev/null; then
  put 644 conf/zz-no-gpu-in-initrd.conf /etc/dracut.conf.d/zz-no-gpu-in-initrd.conf
else
  echo "   Not dracut: remove i915 and amdgpu from MODULES in /etc/mkinitcpio.conf and its kms hook, then rebuild."
fi

echo "== 3. Sleep: s2idle, lid = suspend, wake hook"
put 644 conf/s2idle.conf /etc/systemd/sleep.conf.d/s2idle.conf
put 644 conf/lid.conf /etc/systemd/logind.conf.d/lid.conf
put 755 bin/mac-sleep /usr/lib/systemd/system-sleep/mac-sleep
put 755 bin/mac-wake-display /usr/local/bin/mac-wake-display
put 644 udev/62-t1-no-wakeup.rules /etc/udev/rules.d/62-t1-no-wakeup.rules
put 644 udev/63-tb-xhci-awake.rules /etc/udev/rules.d/63-tb-xhci-awake.rules

echo "== 4. Thunderbolt/USB-C survive sleep: tb-lc-keep (DKMS)"
command -v dkms >/dev/null || { echo "dkms missing: pacman -S dkms linux-headers" >&2; exit 1; }
run rm -rf /usr/src/tb-lc-keep-1.0
run cp -r "$REPO/tb-lc-keep" /usr/src/tb-lc-keep-1.0
dkms status tb-lc-keep/1.0 2>/dev/null | grep -q . && run dkms remove tb-lc-keep/1.0 --all
run dkms install tb-lc-keep/1.0
run sh -c 'echo tb_lc_keep > /etc/modules-load.d/tb-lc-keep.conf'

echo "== 5. Kernel line: pcie_ports=native (USB-C hotplug)"
if [ -f /etc/kernel/cmdline ]; then
  if grep -qw pcie_ports=native /etc/kernel/cmdline; then
    echo "   already set"
  else
    run cp /etc/kernel/cmdline /etc/kernel/cmdline.bak-power
    run sed -i 's/$/ pcie_ports=native/' /etc/kernel/cmdline
  fi
else
  echo "   Add pcie_ports=native to your boot loader's kernel line by hand."
  echo "   Without it, udev/63-tb-xhci-awake.rules keeps USB-C hotplug working at a small power cost."
fi

if [ $DGPU = 1 ]; then
  echo "== 6. Radeon off at boot"
  put 755 bin/dgpu-off /usr/local/bin/dgpu-off
  put 755 bin/dgpu-off-enable /usr/local/bin/dgpu-off-enable
  put 755 bin/dgpu-off-disable /usr/local/bin/dgpu-off-disable
  put 644 systemd/dgpu-off.service /etc/systemd/system/dgpu-off.service
fi

echo "== Enable and rebuild"
run systemctl daemon-reload
run udevadm control --reload
run systemctl enable gmux-igd.service gpu-prefs-guard.service
[ $DGPU = 1 ] && run systemctl enable dgpu-off.service
if command -v reinstall-kernels >/dev/null; then
  run reinstall-kernels
elif command -v mkinitcpio >/dev/null; then
  run mkinitcpio -P
elif command -v dracut >/dev/null; then
  run dracut --regenerate-all --force
fi

cat <<'MSG'

Done. Before you reboot:
- Hyprland: render on the Intel GPU. In hyprland.lua:
    hl.env("AQ_DRM_DEVICES", "/dev/dri/intel")
  or in hyprland.conf:  env = AQ_DRM_DEVICES,/dev/dri/intel
- hypridle with a Lua config: write dpms as hl.dsp.dpms({action = "on"}).
  The string form hl.dsp.dpms("on") toggles, so the panel goes dark after wake.
Then reboot. A plain reboot may land in macOS: hold Option and pick Linux.
MSG
