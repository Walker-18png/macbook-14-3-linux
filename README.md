# MacBookPro14,3 Linux starter kit

Everything that took work to get running on a 2017 15-inch MacBook Pro (T1 chip, 14,3) under Linux.

| Part | What it fixes | Folder |
|---|---|---|
| Touch Bar | Function row shows and keys work (AJ-dev-i60 driver) | [touchbar/](touchbar/README.md) |
| Speakers | Internal speakers, via the CS8409 Apple driver | [audio/](audio/README.md) |
| Wi-Fi | 5 GHz networks show up (board NVRAM file) | [wifi/](wifi/README.md) |
| Sleep and graphics | Lid sleep, key-press wake (s2idle), Intel on the panel, Thunderbolt and USB-C survive sleep. **Costs you the Radeon and external monitors** in Linux | [power/](power/README.md) |
| Kernel updates | A kernel upgrade that would break a DKMS driver aborts before it installs | [kernel-updates/](kernel-updates/README.md) |

Tested on MacBookPro14,3 with Arch Linux. Kernel versions are in the [tested-on log](#tested-on).

## Distributions

We built and tested the kit on Arch. The installers read `/etc/os-release` and also handle
Fedora, Ubuntu, Debian, openSUSE and distributions based on them. Nobody has run those paths on a
Mac yet. If you do, report the result with the bug template, failures included.

| Part | Arch and Arch-based | Fedora, Ubuntu, Debian, openSUSE |
|---|---|---|
| Wi-Fi | Tested | Same file copy, untested |
| Speakers | AUR package through yay, tested | Upstream's DKMS installer, untested |
| Touch Bar | Tested | DKMS and headers from dnf, apt or zypper, untested |
| Sleep and graphics | Tested on EndeavourOS with systemd-boot and dracut | Kernel line through grubby or `/etc/default/grub`, untested. Ubuntu and Debian need a manual initramfs check |
| Kernel updates | pacman hooks | Not available. DKMS still rebuilds on kernel updates, without the pre-install check |

The power kit's two kprobe modules arm only on the 7.2 kernel series. On another series they stay
off, and Thunderbolt and USB-C stop working after the first sleep. See
[Runtime kernel patches](power/README.md#runtime-kernel-patches).

Authorship: Claude (Anthropic) wrote almost all of this kit: the installer scripts, the READMEs, and the troubleshooting notes. Walker-18png directed the work, tested it on the MacBook, and published it.

## Order

1. **Wi-Fi.** `cd wifi && sudo ./install-wifi.sh`, then reboot.
2. **Speakers.** Check EFI partition space first (see [audio/README.md](audio/README.md)), then
   `cd audio && ./install-audio.sh`, then reboot.
3. **Touch Bar.** `cd touchbar && sudo ./install-touchbar.sh`, then reboot.
4. **Sleep and graphics.** `cd power && sudo ./install-power.sh --dgpu-off`, set `AQ_DRM_DEVICES`, then reboot.
5. **Kernel updates (Arch only).** `cd kernel-updates && sudo ./install-kernel-updates.sh`.

Each folder has its own README with verify steps, troubleshooting, and removal.

## Releases

Tagged releases mark states confirmed on the hardware. Pin one instead of tracking `main`:

```sh
git clone --branch v1.0.0 https://github.com/Walker-18png/macbook-14-3-linux
```

The [releases page](https://github.com/Walker-18png/macbook-14-3-linux/releases) lists the tags.

## Tested on

One line per kernel confirmed on a MacBookPro14,3. "All" means every folder's verify steps passed.

| Date | Kernel | Kit version | Result |
|---|---|---|---|
| 2026-10-17 | 7.2.9-arch1-1 | v1.0.0 | All |

## Reporting a bug

Open an issue with the bug template. It asks for the model identifier
(`cat /sys/class/dmi/id/product_name`), the kernel (`uname -r`) and the matching `dmesg` lines.

## Safety

- The T1 firmware lives in the EFI partition (`EFI/APPLE/EMBEDDEDOS/combined.memboot`). Do not delete it.
- The Touch Bar driver must load with `skip_acpi_power=1`. The installer sets it. Without it, loading the
  module freezes a T1.
- Each installer changes system files. Keep a backup or a snapshot before you run them.

## Licences

- `touchbar/apple-ib-drv/`: GPL-2.0, from [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar).
  Upstream licence in `touchbar/LICENSE-upstream`. [Upstream sources](#upstream-sources) names the
  exact commits.
- `audio/`: installs the GPL-2.0 driver [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro).
  Nothing from it is copied into this repo.
- `wifi/brcmfmac43602-pcie.txt`: board data for this model. The `macaddr` is Broadcom's placeholder.

## Upstream sources

The Touch Bar driver came in as an unmodified copy and changed afterwards in this repo's history.
Diff it against upstream yourself:

| Source | Commit | Relation |
|---|---|---|
| [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) | [`f089319`](https://github.com/AJ-dev-i60/t1-touchbar/commit/f089319655853eb90af1ec620ebb6908591f0b2c) (tag `v0.3.0`) | `apple-ib-drv/` imported byte for byte in this repo's first commit, `f2d79de` |
| [t2linux/apple-ib-drv](https://github.com/t2linux/apple-ib-drv) | [`4afd309`](https://github.com/t2linux/apple-ib-drv/commit/4afd30950a7364b06b8cef8a34d6cc6653ca3120) | AJ-dev-i60's base. Their changes are in `touchbar/apple-ib-drv/t1-kernel7-fixes.applied.patch` |

```sh
# Changes this repo made to the driver since the import
git diff f2d79de -- touchbar/apple-ib-drv

# Check that the import matches upstream v0.3.0 (both print the same tree hash)
git rev-parse f2d79de:touchbar/apple-ib-drv
git clone https://github.com/AJ-dev-i60/t1-touchbar /tmp/t1-touchbar
git -C /tmp/t1-touchbar rev-parse v0.3.0:apple-ib-drv
```
