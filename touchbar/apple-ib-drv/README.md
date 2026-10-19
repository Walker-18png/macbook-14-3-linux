# apple-ib-drv: the T1 Touch Bar kernel driver

This kernel driver makes the T1's own firmware draw the Touch Bar: the familiar Esc, brightness,
keyboard backlight, media and volume strip, with **hold Fn for F1 to F12**, as on macOS.
`../install-arch.sh` installs it.

The firmware does the drawing, so the driver needs no daemon. The T1 draws the strip in USB
**config 1** and nothing holds the device open. The **FaceTime webcam keeps working**: the udev
rule that forces config 1 exposes both the Touch Bar HID and the camera's UVC interfaces.

## License and provenance

**GPL-2.0** (see `LICENSE`). The installer scripts one folder up are MIT.

This copy comes from [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) at
[`f089319`](https://github.com/AJ-dev-i60/t1-touchbar/commit/f089319655853eb90af1ec620ebb6908591f0b2c)
(`v0.3.0`). That project forks [t2linux/apple-ib-drv](https://github.com/t2linux/apple-ib-drv) at
[`4afd309`](https://github.com/t2linux/apple-ib-drv/commit/4afd30950a7364b06b8cef8a34d6cc6653ca3120)
and adds fixes so the driver builds and binds on **Linux 7.x** for the **T1** (`05ac:8600`,
MacBookPro13,x and 14,x).

`t1-kernel7-fixes.applied.patch` records the delta against t2linux. The `.c` sources here already
contain it, so the DKMS build needs no patching. Don't apply it again: `patch --dry-run` reports
"previously applied".

Fixes 1 to 5 came from AJ-dev-i60. This repo added fix 6 and the sleep fixes listed in
[power/](../../power/README.md). `git diff f2d79de -- touchbar/apple-ib-drv` shows every change made
here since the import.

The six fixes:

1. **`skip_acpi_power`, a freeze guard that is on by default ⭐.** The `ASOC.SOCW(1)` ACPI power-on
   **hard-freezes** the T1 (confirmed on MacBookPro14,3) at module load and on resume. The
   parameter takes three values. `-1`, the default, skips the power-on on the T1 family
   (MacBookPro13,x and 14,x), detected by DMI, and also skips it when DMI is unreadable. A bare
   `insmod` therefore can't freeze the machine. `1` forces the skip, and the installer pins it in
   modprobe.d as a second guard. `0` forces the upstream power-on and **can freeze the machine**.
   All three SOCW call sites (probe, suspend, resume) honour it. Upstream left suspend and resume
   unguarded.
2. UBSAN out-of-bounds in `appleib_add_device`: index by slot, not by collection index.
3. `appleib_ll_parse` did nothing. It now calls `hid_parse_report` again, which fixes `-ENODEV` on
   the sub-device.
4. T1 activation with the mode interface alone. The bar comes up without the display interface,
   and the firmware renders the row itself.
5. NULL guard on the sparse `sub_hdevs[]`, which crashed on USB autosuspend.
6. **Display control on the T1.** The T1 has a display interface (iBridge input3, usage
   `ff12.0021`, in one report with `ff12.0020`). Earlier builds turned every display command into
   a no-op on the T1, so `dim_timeout` and `idle_timeout` never dimmed or blanked the bar. The
   driver now sends display commands whenever that interface is present and skips them only when
   it is missing. This does not fix a bar left dark by an ACPI S4 hibernate: see
   [power/](../../power/README.md#hibernate).

## How it's installed

`../install-arch.sh` installs it with **DKMS**, so it rebuilds on kernel upgrades:

```
dkms add/build/install (this source as apple-ib-drv/0.1)
/etc/modprobe.d/apple-touchbar.conf        -> options apple_ibridge skip_acpi_power=1   ⭐ required
/etc/modprobe.d/blacklist-appletbdrm.conf  -> keeps the T2 Touch Bar driver off the iBridge
/etc/modules-load.d/apple-touchbar.conf    -> apple-ibridge (auto-load at boot)
/etc/udev/rules.d/99-ibridge.rules         -> force USB config 1 + disable autosuspend
```

`packaging/` holds those four files. The driver already skips the freeze on T1 hardware, so
`skip_acpi_power=1` in modprobe.d is a second guard. **Never pass `skip_acpi_power=0`**: it forces
`SOCW(1)` and freezes the machine.

## Recovery

If a boot misbehaves, add `modprobe.blacklist=apple_ibridge,apple_touchbar` to the kernel command
line (GRUB: press `e`), boot, and investigate.
