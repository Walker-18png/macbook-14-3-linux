# T1 Touch Bar on Arch Linux

Makes the Touch Bar on a 2016-2017 MacBook Pro (T1, `05ac:8600` iBridge) show the function row
on Arch Linux. The T1's own firmware draws the strip. This repo installs the kernel driver that
talks to it.

Tested on: MacBookPro14,3, Arch Linux, kernel 7.2.9-arch1-1.

## Requirements

- A T1 MacBook Pro with its firmware intact. Check that `/boot/EFI/APPLE/EMBEDDEDOS/combined.memboot`
  exists. If you use a separate EFI mount, check the path on that mount.
- Arch Linux with kernel headers for the running kernel (`linux-headers`).
- Secure Boot off. With Secure Boot on, enrol the DKMS key first: `sudo mokutil --import /var/lib/dkms/mok.pub`.

## Install

```sh
git clone https://github.com/Walker-18png/t1-touchbar-arch
cd t1-touchbar-arch
sudo ./install-arch.sh
sudo reboot
```

Add `--dry-run` to print the steps without running them.

After the reboot, the function row should show. Hold fn for F1 to F12, or release it for media keys.

## What the installer does

1. Removes the older `appleibridge` DKMS module and `/etc/modprobe.d/apple-ib-tb.conf`, if present.
   Both claim the iBridge and conflict with this driver.
2. Builds and installs the driver (`apple-ib-drv` 0.1) with DKMS.
3. Writes `/etc/modprobe.d/apple-touchbar.conf`, which sets `skip_acpi_power=1`. This is required.
   Without it, loading the module runs `ASOC.SOCW(1)` and freezes the T1.
   Also blacklists `appletbdrm`, the T2 Touch Bar driver: on a T1 it fails its probe (-11) on the
   iBridge display interface.
4. Adds a udev rule that puts the iBridge in USB configuration 1, and a modules-load entry so the
   driver loads at boot.
5. Loads the driver and prints a short self-check.

## Verify

```sh
lsmod | grep apple            # apple_touchbar and apple_ibridge loaded
dmesg | grep -i skip_acpi     # "NOT running ASOC.SOCW(1)"
dmesg | grep -i apple-touchbar.*input   # Touch Bar input created
```

## Dim and off when idle

The driver dims the bar and then turns it off after a stretch without keyboard, trackpad, or
Touch Bar input. Any input brings it back. The defaults are off after 5 minutes and dim shortly
before that. To change them, add a line to `/etc/modprobe.d/apple-touchbar.conf`:

```
options apple_touchbar dim_timeout=15 idle_timeout=30
```

Values are in seconds; `-1` disables that step. The driver is in the initramfs, so rebuild it
(`sudo reinstall-kernels` on EndeavourOS, `sudo mkinitcpio -P` with mkinitcpio) and reboot. To try
values without rebooting, write them to `idle_timeout` and `dim_timeout` under
`/sys/bus/hid/drivers/apple-touchbar/*/`.

## Troubleshooting

- **Bar still dark after reboot.** `usbmuxd` matches the iBridge in its udev rule and can claim it
  first. Check with `systemctl is-active usbmuxd`. If you don't tether iPhones or iPads, run
  `sudo systemctl mask usbmuxd` and reboot. Otherwise remove the `05ac.*8600` line from
  `/lib/udev/rules.d/39-usbmuxd.rules` and reboot.
- **Bar lit after sleep, taps do nothing.** `evtest` shows only `KEY_UNKNOWN` (240) per tap. The
  driver thought the bar was still off: sleep set its mode to OFF, and the T1 mode-set returns the
  byte count, which the driver never counted as success. Fixed in this source; rebuild with DKMS
  and reboot. Older builds recover only by reboot.
- **Bar dark after waking from hibernate, or never dims.** Builds before the T1 display fix threw
  away every display command, so nothing could switch the bar's display back on after a
  hibernate, and dimming did nothing. Fixed in this source (dimming confirmed on a
  MacBookPro14,3; the hibernate case relies on the same fix but is not yet confirmed). Rebuild
  with DKMS, rebuild the initramfs, and reboot.
- **`tainting kernel` in dmesg.** Expected with Secure Boot off. The module is self-signed.
- **Install fails at build.** Check that `linux-headers` matches `uname -r`. The driver source
  targets kernel 7.x. Report the kernel version with the build error.
- **Machine freezes at module load.** The freeze guard was not in place. Power-cycle the machine,
  then check `/etc/modprobe.d/apple-touchbar.conf` contains `skip_acpi_power=1`.

## Remove

```sh
sudo ./uninstall-arch.sh
sudo reboot
```

## Credits and licenses

The driver source in `apple-ib-drv/` is from
[AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar), which builds on the
kernel-6 work of the T1 reverse-engineering projects it cites. It is GPL-2.0, see
`apple-ib-drv/LICENSE`. The original repo's license is in `LICENSE-upstream`.

The installer scripts in this repo are a pacman port of the upstream `install.sh`, under the same
MIT license as upstream (`LICENSE-upstream`).
