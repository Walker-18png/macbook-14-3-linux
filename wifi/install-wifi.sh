#!/usr/bin/env bash
#
# Wi-Fi on the MacBookPro14,3 (BCM43602, brcmfmac). Installs a board NVRAM file so the card
# sees 5 GHz networks. Without it, only 2.4 GHz shows up.
#   sudo ./install-wifi.sh
#
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")" && pwd)"
DEST=/usr/lib/firmware/updates/brcm/brcmfmac43602-pcie.txt

install -Dm644 "$REPO/brcmfmac43602-pcie.txt" "$DEST"
echo "Installed $DEST"
echo "Reboot so brcmfmac loads the new NVRAM:  sudo reboot"
echo "After reboot, check 5 GHz with:  iw dev wlan0 scan | grep freq | sort -u"
