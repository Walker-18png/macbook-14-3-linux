#!/usr/bin/env bash
#
# Speakers for the MacBookPro14,3 (CS8409 codec, subsystem 0x106b3900).
# Installs the snd-hda-macbookpro DKMS driver, then checks the boot log.
#   Arch:       from the AUR with yay (tested)
#   Elsewhere:  upstream's own DKMS installer, cloned to /usr/local/src (untested)
#   ./install-audio.sh          (run as your normal user, not root)
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
LIB="$REPO/../lib/distro.sh"
. "$LIB"
UPSTREAM=https://github.com/davidjo/snd_hda_macbookpro
SRC=/usr/local/src/snd_hda_macbookpro

[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user. The script asks for sudo itself." >&2; exit 1; }
if [ "$DISTRO" = arch ]; then
  command -v yay >/dev/null || { echo "yay is required (AUR helper)." >&2; exit 1; }
elif [ "$DISTRO" = unknown ]; then
  echo "Unknown distribution. Follow the install steps in $UPSTREAM." >&2; exit 1
fi

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

if [ "$DISTRO" = arch ]; then
  # A -git package builds whatever upstream has today. yay shows the PKGBUILD diff: read it
  # before you accept.
  echo "yay will show the PKGBUILD. Read it before you accept: it builds the latest upstream commit."
  yay -S --needed snd-hda-macbookpro-dkms-git
else
  # Upstream's DKMS build downloads the matching kernel source with wget on every kernel update.
  # shellcheck disable=SC2046
  sudo bash -c '. "$1"; shift; pkg_install "$@"' _ "$LIB" $(dkms_deps) git patch wget
  if [ -d "$SRC/.git" ]; then
    sudo git -C "$SRC" pull --ff-only
  else
    sudo git clone "$UPSTREAM" "$SRC"
  fi
  echo
  echo "Upstream commit: $(git -C "$SRC" log -1 --format='%h %cs %s')"
  echo "It runs as root. Read $SRC/install.cirrus.driver.sh and $SRC/dkms.sh first."
  read -r -p "Install it with DKMS? [y/N] " ok
  [ "$ok" = y ] || [ "$ok" = Y ] || { echo "Stopped. Nothing installed."; exit 1; }
  sudo bash -c 'cd "$1" && ./install.cirrus.driver.sh -i' _ "$SRC"
fi

echo
echo "Reboot, then run:  dmesg | grep -i cs8409"
echo "Working load shows:  Primary patch_cs8409 NOT FOUND trying APPLE  and  autoconfig for CS8409"
echo "If it shows:         UNKNOWN subsystem id 0x10138409"
echo "  the firmware boot data is corrupt. See the notes in README.md (NVRAM reset and bootloader reinstall)."
