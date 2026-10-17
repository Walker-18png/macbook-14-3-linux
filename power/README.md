# Sleep and hybrid graphics

Makes the MacBookPro14,3 sleep when you close the lid and wake on a key press, with the Intel
GPU on the panel and the Radeon off. Wi-Fi, Thunderbolt, USB-C and the Touch Bar all come back
after wake.

Tested on MacBookPro14,3, EndeavourOS (Arch), kernel 7.2.9-arch1-1, Hyprland with hypridle.

## Scope: read before you install

We worked this out on one machine. Other 14,3s can differ, so check yours against this list.

| Part | Tested configuration |
|---|---|
| Intel GPU | HD Graphics 630, `8086:591b` at `00:02.0` |
| Radeon | Radeon Pro 555 (Polaris 11), `1002:67ef`, Apple subsystem `106b:017a`, at `01:00.0` |
| Firmware | Apple EFI 529.140.2.0.0 |
| Boot | systemd-boot through `kernel-install` (`/etc/kernel/cmdline`, `reinstall-kernels`), dracut initrd |
| Desktop | Hyprland with a Lua config (`hyprland.lua`), hypridle, a quickshell lock screen |

- **GPU.** The 14,3 shipped with a Radeon Pro 555 or 560. Only the 555 was tested. The gmux,
  `gpu-power-prefs` and vga_switcheroo steps should apply to the 560 too. The PCI addresses are
  hard-coded in `udev/61-gpu-names.rules` and `bin/mac-sleep`. The installer checks both GPUs and
  stops on a mismatch; `--force` skips the check. Compare yours with `lspci -nn | grep VGA`.
- **Firmware.** The EC lid wake, the `gpu-power-prefs` value and the gmux registers come from this
  firmware's ACPI tables. A different macOS or firmware version can change them.
- **Hyprland.** These parts are Hyprland-only: `mac-wake-display` (panel on after wake, hypridle
  restart), the hypridle kill in `mac-sleep`, `AQ_DRM_DEVICES`, and the dpms toggle fix. The hook
  skips the panel step when Hyprland isn't running. On GNOME, KDE or Sway, the compositor turns the
  panel back on itself; point it at `/dev/dri/intel` in its own way. Everything else (s2idle, EC lid
  wake, gmux, Radeon off, Thunderbolt, USB-C, fans, keyboard light) works without a desktop.
- **Boot loader.** GRUB and mkinitcpio users add `pcie_ports=native` by hand and remove i915 and
  amdgpu from the initrd themselves. The installer says so.

## Install

```sh
cd power
sudo ./install-power.sh --dgpu-off     # leave out --dgpu-off to keep the Radeon powered
```

Then set `AQ_DRM_DEVICES` as the installer says, and reboot. Hold Option at the chime and pick Linux:
a plain reboot may land in macOS. Install [touchbar/](../touchbar/README.md) first if you want the
Touch Bar to survive sleep; its driver carries the resume fix.

`--dry-run` prints the steps. `sudo ./uninstall-power.sh` removes everything.

## What it fixes

| Problem | Cause | Fix |
|---|---|---|
| Deep sleep (S3), and hibernate with the Radeon driven, wake to a black or console screen, or reboot | Apple firmware re-POSTs the Radeon only at cold boot; amdgpu fails "SMU load firmware". Wi-Fi firmware and Thunderbolt die in S3 too | `conf/s2idle.conf`: s2idle only |
| Opening the lid never wakes the machine | The lid reports through the embedded controller (EC query `_Q20`), and Linux leaves the EC disabled in `/proc/acpi/wakeup`. LID0's own wake GPE (0x6F) never fires | `mac-sleep` hook enables EC wake before each sleep. This helps only for short sleeps: see Not working |
| Panel on the Radeon, Radeon can't sleep | EFI variable `gpu-power-prefs` picks the GPU at power-on | `gpu-prefs-guard` keeps it on Intel at every boot |
| After a macOS boot, Linux shows a console only (i915 "disabling eDP") | macOS resets `gpu-power-prefs` to the Radeon | `gmux-igd` switches the gmux mux to Intel before i915 loads, so this boot still gets the panel |
| Panel shows up as eDP-2, scripts that use eDP-1 break | amdgpu probed first and took the eDP-1 name | amdgpu blacklisted from autoload; `dgpu-off` loads it by name after i915 |
| Radeon idles at about 10 W with no driver | Driverless Radeon stays in D0, ungated | `dgpu-off` powers it off through vga_switcheroo. Idle draw drops from about 23 W to 12 W |
| Thunderbolt and USB-C gone after the first sleep (`tb_cfg_read: -108`) | The kernel sets the LC sleep bit on the host routers and the chip stops answering | `tb-lc-keep` (DKMS) skips that call in s2idle only. Carry of omarchy-pkgs PR #596 patch 0664 |
| USB-C ports ignore a plug-in | Apple's `_OSC` withholds native PME, so the runtime-suspended Alpine Ridge xHCIs never wake | `pcie_ports=native` on the kernel line. Fallback without it: `udev/63-tb-xhci-awake.rules` |
| Wi-Fi gone after wake, `brcmf` dcmd timeouts until reboot | The BCM43602 firmware hangs across s2idle | Hook unloads `brcmfmac` before sleep and reloads it after wake |
| Wi-Fi and Thunderbolt dead after wake | Firmware won't bring them back from D3cold | Hook pins them powered during sleep, restores runtime PM after |
| Wake stalls for seconds per Thunderbolt controller | During resume a bridge's Primary Bus register can still read 0, so ACPICA maps Apple's UPSB config regions onto host bridge 00:00.0 and the firmware polls the wrong device | `acpi-bridge-bus` (DKMS) keeps the parent-derived bus. Carry of ACPICA PR #1235 (omarchy-pkgs #544, patch 0771) |
| Fans run at 2000 rpm and the keyboard stays lit while asleep | The SMC keeps them going in s2idle | Hook stops fans below 85 °C and turns the backlight off |
| Spurious wakes | The T1 iBridge is a wake source | `udev/62-t1-no-wakeup.rules` |
| Touch Bar stays dark after wake | s2idle calls `.resume`, the driver only had `.reset_resume`, and its resume test required the display interface | Patched in `touchbar/apple-ib-drv/apple-touchbar.c` |
| Hibernate aborts back to the lock screen (`amdgpu_pmops_freeze returns -22`) | amdgpu's freeze callback resets the Radeon even when vga_switcheroo has switched it off, and that reset fails at random. Its `suspend_noirq` callback already skips a switched-off GPU | `mac-hibernate` runs one 3 s s2idle cycle first: the Radeon then sits in D3cold, where the reset passed in every test. Kernel fix: `amdgpu-freeze-switcheroo-off.patch` (not upstream, not built) |
| Hibernate powers off, then the Mac turns itself back on within seconds | `mac-sleep` makes the EC a wake source for lid wake, and the EC can wake the Mac from ACPI S4 | `conf/hibernate.conf`: `HibernateMode=shutdown`, a plain S5 power-off |
| Touch Bar stays dark after waking from hibernate | The ACPI S4 wake leaves the T1's display off. The driver's mode and display commands are accepted, and even a fresh re-probe (re-applying USB configuration 1) doesn't light it | `conf/hibernate.conf`: from S5 the firmware takes its cold-boot path and the bar comes back. Confirmed on a MacBookPro14,3 |
| Touch Bar lit after wake, taps send `KEY_UNKNOWN` | Sleep marks the bar OFF; the T1 mode-set returns 1 (bytes sent) and the driver records the new mode only on 0 | Patched in `touchbar/apple-ib-drv/apple-touchbar.c` |
| Hyprland: panel goes dark or flashes after wake | With a Lua config, `hl.dsp.dpms("on")` ignores its argument and toggles | Use `hl.dsp.dpms({action = "on"})` in hypridle.conf. `mac-wake-display` does |

In s2idle the machine draws about 11 W. That is the platform's floor: the package never gets past PC3.

## Files

| Installed as | From |
|---|---|
| `/usr/lib/systemd/system-sleep/mac-sleep` | `bin/mac-sleep` |
| `/usr/local/bin/mac-wake-display` | `bin/mac-wake-display` |
| `/usr/local/bin/gmux-igd` + `gmux-igd.service` | `bin/`, `systemd/` |
| `/usr/local/bin/gpu-prefs-guard` + `gpu-prefs-guard.service` | `bin/`, `systemd/` |
| `/usr/local/bin/dgpu-off{,-enable,-disable}` + `dgpu-off.service` | `bin/`, `systemd/` (with `--dgpu-off`) |
| `/etc/systemd/sleep.conf.d/s2idle.conf`, `/etc/systemd/logind.conf.d/lid.conf` | `conf/` |
| `/etc/systemd/sleep.conf.d/hibernate.conf`, `/usr/local/bin/mac-hibernate` | `conf/`, `bin/` |
| `/etc/modprobe.d/no-amdgpu.conf`, `/etc/dracut.conf.d/zz-no-gpu-in-initrd.conf` | `conf/` |
| `/etc/udev/rules.d/61-gpu-names.rules` (`/dev/dri/intel`, `/dev/dri/radeon`), `62-…`, `63-…` | `udev/` |
| `/usr/src/tb-lc-keep-1.0` (DKMS) | `tb-lc-keep/` |
| `/usr/src/acpi-bridge-bus-1.0` (DKMS) | `acpi-bridge-bus/` |

## Verify

```sh
cat /sys/power/mem_sleep                              # [s2idle]
sudo cat /sys/kernel/debug/vgaswitcheroo/switch       # IGD :+, DIS :Off (with --dgpu-off)
ls /sys/class/drm | grep eDP                          # card?-eDP-1 on the Intel card
grep ^EC /proc/acpi/wakeup                            # *enabled after the first sleep
cat /sys/module/tb_lc_keep/parameters/skipped         # goes up by 2 per sleep
cat /sys/module/acpi_bridge_bus/parameters/{kept,fixed}  # reads checked, reads corrected
journalctl -t mac-sleep -b                            # battery at sleep/wake, panel on
```

Test sleep without the lid: `sudo rtcwake -m no -s 45 && systemctl suspend` wakes after 45 s.

## Hibernate

Works with `--dgpu-off` (tested on kernel 7.2.10). The installer sets the hibernate mode and adds
`mac-hibernate`, but it does not set up hibernation itself: you need swap at least as large as
your RAM and a resume entry for it in the initrd and kernel line. Follow your distro's guide
(Arch wiki: Power management/Suspend and hibernate).

Hibernate with `mac-hibernate`, not `systemctl hibernate`: bind it to a key or a power-menu entry.
When the Radeon isn't in D3cold yet (after every boot and every resume from hibernate), it first
sleeps for 3 s and wakes on its own, then hibernates. Without that cycle the hibernate can abort
back to the lock screen (see What it fixes). The Mac then powers off fully; press the power
button to resume.

```sh
mac-hibernate
journalctl -t mac-sleep -b | grep 'hibernate prep'   # "Radeon D3cold, hibernating"
journalctl -k -b | grep 'image restored'              # after the resume
```

Not tested: hibernate with the Radeon powered and driverless (no `--dgpu-off`).

## Gotchas

- `/proc/acpi/wakeup` toggles on each write. Check the state before you write, as the hook does.
  Don't put it in tmpfiles.d: pacman hooks re-run tmpfiles and switch it back off.
- Never `modprobe amdgpu` by hand while Hyprland runs. Hyprland grabs the Radeon's phantom eDP.
- Never `modprobe -r apple_touchbar` live: kernel Oops.
- An early boot unit ordered before `systemd-udev-trigger` must not order after `local-fs.target`.
  The first `gmux-igd.service` did, and boot hung 90 s on the EFI mount before emergency mode.
- The Mac's boot picker is Apple's. You can't edit the kernel line at boot, so test new
  parameters on a separate boot entry first. In emergency mode, Ctrl+D continues the boot.
- The power button taps as poweroff, not sleep.

## Not working

- Deep S3. It fails on the Radeon. S3 with the Radeon off rebooted the machine, and S3 with the
  Radeon powered and driverless rebooted it into the boot picker. Hibernate works: see Hibernate.
- Lid wake after about a minute of sleep. The lid wakes the machine only if it slept for under
  about a minute (worked at 6 s and 56 s, failed every time from 98 s on). After that, press a key.
  No EC event or wake GPE reaches the host. Our best guess: the SMC drops its lid-wake line
  because s2idle never asserts SLP_S3#, and macOS doesn't hit this because it uses real S3.
  An EC wake timer to re-arm it from a dark wake never fired in s2idle.
- `gmux-igd` after a macOS visit is the least tested part: it should give a normal login screen.
  If the panel stays dark, reboot once; `gpu-prefs-guard` has fixed the variable by then.
