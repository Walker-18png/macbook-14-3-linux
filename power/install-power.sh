#!/usr/bin/env bash
#
# Sleep and hybrid graphics on the MacBookPro14,3. Tested on one machine: HD 630 (8086:591b)
# + Radeon Pro 555 (1002:67ef), Hyprland. See README.md, "Scope".
#   sudo ./install-power.sh              Intel drives the panel, lid sleep (s2idle) works
#   sudo ./install-power.sh --dgpu-off   also power the Radeon off at boot (saves about 10 W)
#   sudo ./install-power.sh --dry-run    print the steps only
#   sudo ./install-power.sh --force      skip the GPU check (untested hardware)
#
set -euo pipefail

DRY=0 DGPU=0 FORCE=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --dgpu-off) DGPU=1 ;;
    --force) FORCE=1 ;;
    *) echo "usage: sudo $0 [--dgpu-off] [--dry-run] [--force]" >&2; exit 2 ;;
  esac
done
[ $DRY = 1 ] || [ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")" && pwd)"
. "$REPO/../lib/distro.sh"
run() { echo "+ $*"; [ $DRY = 1 ] || "$@"; }
put() { run install -Dm"$1" "$REPO/$2" "$3"; }

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [ "$model" != MacBookPro14,3 ]; then
  echo "This is '$model', not a MacBookPro14,3. The gmux, PCI and ACPI paths here are for the 14,3." >&2
  exit 1
fi
igd=$(cat /sys/bus/pci/devices/0000:00:02.0/{vendor,device} 2>/dev/null | tr '\n' ' ' || true)
dgpu=$(cat /sys/bus/pci/devices/0000:01:00.0/{vendor,device} 2>/dev/null | tr '\n' ' ' || true)
if [ "$igd" != "0x8086 0x591b " ] || [ "$dgpu" != "0x1002 0x67ef " ]; then
  echo "GPUs differ from the tested machine (00:02.0 = $igd, 01:00.0 = $dgpu;" >&2
  echo "tested: 0x8086 0x591b and 0x1002 0x67ef). See README.md, Scope." >&2
  [ $FORCE = 1 ] || { echo "Re-run with --force to install anyway." >&2; exit 1; }
fi
command -v Hyprland >/dev/null || echo "Hyprland not found: the panel-on-after-wake step will be skipped. See README.md, Scope."

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
elif command -v mkinitcpio >/dev/null; then
  echo "   mkinitcpio: remove i915 and amdgpu from MODULES in /etc/mkinitcpio.conf and its kms hook, then rebuild."
elif command -v update-initramfs >/dev/null; then
  echo "   initramfs-tools: remove i915 and amdgpu from /etc/initramfs-tools/modules if listed there."
  echo "   Its framebuffer hook can still pull them in. Check with: lsinitramfs /boot/initrd.img-\$(uname -r) | grep -E 'i915|amdgpu'"
fi

echo "== 3. Sleep: s2idle, lid = suspend, wake hook"
put 644 conf/s2idle.conf /etc/systemd/sleep.conf.d/s2idle.conf
put 644 conf/lid.conf /etc/systemd/logind.conf.d/lid.conf
put 644 conf/hibernate.conf /etc/systemd/sleep.conf.d/hibernate.conf
put 755 bin/mac-hibernate /usr/local/bin/mac-hibernate
put 755 bin/mac-sleep /usr/lib/systemd/system-sleep/mac-sleep
put 755 bin/mac-wake-display /usr/local/bin/mac-wake-display
put 755 bin/smc-fans-auto /usr/local/bin/smc-fans-auto
put 644 systemd/smc-fans-auto.service /etc/systemd/system/smc-fans-auto.service
put 644 udev/62-t1-no-wakeup.rules /etc/udev/rules.d/62-t1-no-wakeup.rules
put 644 udev/63-tb-xhci-awake.rules /etc/udev/rules.d/63-tb-xhci-awake.rules

echo "== 4. Thunderbolt/USB-C survive sleep: tb-lc-keep (DKMS)"
# shellcheck disable=SC2046
command -v dkms >/dev/null && have_headers || run pkg_install $(dkms_deps) || true
[ $DRY = 1 ] || { command -v dkms >/dev/null && have_headers; } || {
  echo "Install DKMS and the headers for $(uname -r), then re-run: $(dkms_deps)" >&2; exit 1; }
run rm -rf /usr/src/tb-lc-keep-1.0
run cp -r "$REPO/tb-lc-keep" /usr/src/tb-lc-keep-1.0
dkms status tb-lc-keep/1.0 2>/dev/null | grep -q . && run dkms remove tb-lc-keep/1.0 --all
run dkms install tb-lc-keep/1.0
run sh -c 'echo tb_lc_keep > /etc/modules-load.d/tb-lc-keep.conf'

echo "== 4b. Faster Thunderbolt resume: acpi-bridge-bus (DKMS)"
# Carry of ACPICA PR #1235: firmware stops polling the wrong PCI device for seconds per controller on wake.
run rm -rf /usr/src/acpi-bridge-bus-1.0
run cp -r "$REPO/acpi-bridge-bus" /usr/src/acpi-bridge-bus-1.0
dkms status acpi-bridge-bus/1.0 2>/dev/null | grep -q . && run dkms remove acpi-bridge-bus/1.0 --all
run dkms install acpi-bridge-bus/1.0
run sh -c 'echo acpi_bridge_bus > /etc/modules-load.d/acpi-bridge-bus.conf'

echo "== 5. Kernel line: pcie_ports=native (USB-C hotplug)"
GRUB_REBUILD=0
if grep -qw pcie_ports=native /proc/cmdline /etc/kernel/cmdline /etc/default/grub 2>/dev/null; then
  echo "   already set"
elif [ -f /etc/kernel/cmdline ]; then
  # systemd-boot and UKIs built by kernel-install
  run cp /etc/kernel/cmdline /etc/kernel/cmdline.bak-power
  run sed -i 's/$/ pcie_ports=native/' /etc/kernel/cmdline
elif command -v grubby >/dev/null; then
  # Fedora: GRUB with BLS entries
  run grubby --update-kernel=ALL --args=pcie_ports=native
elif [ -f /etc/default/grub ]; then
  # Debian, Ubuntu, openSUSE, Arch with GRUB
  run cp /etc/default/grub /etc/default/grub.bak-power
  run sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&pcie_ports=native /' /etc/default/grub
  GRUB_REBUILD=1
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
run systemctl enable gmux-igd.service gpu-prefs-guard.service smc-fans-auto.service
[ $DGPU = 1 ] && run systemctl enable dgpu-off.service
if command -v reinstall-kernels >/dev/null; then
  run reinstall-kernels
elif command -v mkinitcpio >/dev/null; then
  run mkinitcpio -P
elif command -v dracut >/dev/null; then
  run dracut --regenerate-all --force
elif command -v update-initramfs >/dev/null; then
  run update-initramfs -u -k all
fi
if [ $GRUB_REBUILD = 1 ]; then
  if command -v update-grub >/dev/null; then run update-grub
  elif command -v grub2-mkconfig >/dev/null; then run grub2-mkconfig -o /boot/grub2/grub.cfg
  else run grub-mkconfig -o /boot/grub/grub.cfg
  fi
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
