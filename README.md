# MacBookPro14,3 Linux starter kit

Everything that took work to get running on a 2016 MacBook Pro (T1 chip, 14,3) under Arch Linux:

| Part | What it fixes | Folder |
|---|---|---|
| Touch Bar | Function row shows and keys work (AJ-dev-i60 driver, Arch port) | [touchbar/](touchbar/README.md) |
| Speakers | Internal speakers, via the CS8409 Apple driver (AUR) | [audio/](audio/README.md) |
| Wi-Fi | 5 GHz networks show up (board NVRAM file) | [wifi/](wifi/README.md) |

Tested on MacBookPro14,3, Arch Linux, kernel 7.2.9-arch1-1.

## Order

1. **Wi-Fi.** `cd wifi && sudo ./install-wifi.sh`, then reboot.
2. **Speakers.** Check EFI partition space first (see [audio/README.md](audio/README.md)), then
   `cd audio && ./install-audio.sh`, then reboot.
3. **Touch Bar.** `cd touchbar && sudo ./install-arch.sh`, then reboot.

Each folder has its own README with verify steps, troubleshooting, and removal.

## Safety

- The T1 firmware lives in the EFI partition (`EFI/APPLE/EMBEDDEDOS/combined.memboot`). Do not delete it.
- The Touch Bar driver must load with `skip_acpi_power=1`. The installer sets it. Without it, loading the
  module freezes a T1.
- Each installer changes system files. Keep a backup or a snapshot before you run them.

## Licences

- `touchbar/apple-ib-drv/`: GPL-2.0, from [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar).
  Upstream licence in `touchbar/LICENSE-upstream`.
- `audio/`: installs the GPL-2.0 driver [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro).
  Nothing from it is copied into this repo.
- `wifi/brcmfmac43602-pcie.txt`: board data for this model. The `macaddr` is Broadcom's placeholder.
