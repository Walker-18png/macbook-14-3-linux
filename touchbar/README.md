# T1 Touch Bar

Makes the Touch Bar on a 2016-2017 MacBook Pro (T1, `05ac:8600` iBridge) show the function row
on Linux. The T1's own firmware draws the strip. This folder installs the kernel driver that
talks to it.

Tested on MacBookPro14,3. Kernel versions are in the [tested-on log](../README.md#tested-on).

## Requirements

- A T1 MacBook Pro with its firmware intact. Check that `/boot/EFI/APPLE/EMBEDDEDOS/combined.memboot`
  exists. If you use a separate EFI mount, check the path on that mount.
- DKMS and the headers for the running kernel. The installer installs both with pacman, dnf, apt
  or zypper. Only the Arch path is tested.
- Secure Boot off. With Secure Boot on, enrol the DKMS key first: `sudo mokutil --import /var/lib/dkms/mok.pub`.

## Install

Run the installer from this repo's `touchbar/` folder:

```sh
cd macbook-14-3-linux/touchbar
sudo ./install-touchbar.sh
sudo reboot
```

Add `--dry-run` to print the steps without running them.

After the reboot, the function row should show. Hold fn for F1 to F12, or release it for media keys.

## What the installer does

1. Removes the older `appleibridge` DKMS module and `/etc/modprobe.d/apple-ib-tb.conf`, if present.
   Both claim the iBridge and conflict with this driver.
2. Installs DKMS and the kernel headers, then builds and installs the driver (`apple-ib-drv` 0.1) with DKMS.
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
- **Bar never dims or turns off.** Builds before the T1 display fix threw away every display
  command, so `dim_timeout` and `idle_timeout` did nothing. Fixed in this source (confirmed on a
  MacBookPro14,3). Rebuild with DKMS, rebuild the initramfs, and reboot.
- **Bar dark after waking from hibernate.** The ACPI S4 wake leaves the T1's display off, and no
  driver command brings it back. Hibernate with `HibernateMode=shutdown` instead; the power
  installer sets it ([power/](../power/README.md#hibernate)). A dark bar now needs a reboot.
- **`tainting kernel` in dmesg.** Expected with Secure Boot off. The module is self-signed.
- **Install fails at build.** Check that `linux-headers` matches `uname -r`. The driver source
  targets kernel 7.x. Report the kernel version with the build error.
- **Machine freezes at module load.** The freeze guard was not in place. Power-cycle the machine,
  then check `/etc/modprobe.d/apple-touchbar.conf` contains `skip_acpi_power=1`.

## Remove

```sh
sudo ./uninstall-touchbar.sh
sudo reboot
```

## Credits and licenses

The driver source in `apple-ib-drv/` is from
[AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) at
[`f089319`](https://github.com/AJ-dev-i60/t1-touchbar/commit/f089319655853eb90af1ec620ebb6908591f0b2c)
(`v0.3.0`), which builds on the kernel-6 work of the T1 reverse-engineering projects it cites.
[Upstream sources](../README.md#upstream-sources) shows how to diff this copy against it. It is GPL-2.0, see
`apple-ib-drv/LICENSE`. The original repo's license is in `LICENSE-upstream`.

`install-touchbar.sh` and `uninstall-touchbar.sh` port upstream's apt-based `install.sh` and
`uninstall.sh` to pacman, dnf, apt and zypper. They keep upstream's MIT license (`LICENSE-upstream`).
