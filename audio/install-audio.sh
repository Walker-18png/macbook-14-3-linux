#!/usr/bin/env bash
#
# Speakers for the MacBookPro14,3 (CS8409 codec, subsystem 0x106b3900).
# Installs the snd-hda-macbookpro DKMS driver from the AUR, then checks the boot log.
#   ./install-audio.sh          (run as your normal user, not root)
#
set -euo pipefail

[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user. yay asks for sudo itself." >&2; exit 1; }
command -v yay >/dev/null || { echo "yay is required (AUR helper)." >&2; exit 1; }

# The driver's initrd step writes into the EFI partition. A full ESP makes it fail with
# "No space left on device". Check before installing.
if mountpoint -q /efi 2>/dev/null || mountpoint -q /boot/efi 2>/dev/null; then
  esp=$(mountpoint -q /efi && echo /efi || echo /boot/efi)
  free=$(df -m --output=avail "$esp" | tail -1 | tr -d ' ')
  echo "ESP $esp has ${free} MB free."
  if [ "$free" -lt 60 ]; then
    echo "Free space first. Remove old initrd-fallback files from the ESP, then re-run." >&2
    exit 1
  fi
fi

# A -git package builds whatever upstream has today. yay shows the PKGBUILD diff: read it
# before you accept.
echo "yay will show the PKGBUILD. Read it before you accept: it builds the latest upstream commit."
yay -S --needed snd-hda-macbookpro-dkms-git

echo
echo "Reboot, then run:  dmesg | grep -i cs8409"
echo "Working load shows:  Primary patch_cs8409 NOT FOUND trying APPLE  and  autoconfig for CS8409"
echo "If it shows:         UNKNOWN subsystem id 0x10138409"
echo "  the firmware boot data is corrupt. See the notes in README.md (NVRAM reset and bootloader reinstall)."
