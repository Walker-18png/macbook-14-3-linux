#!/usr/bin/env bash
#
# Bluetooth on the MacBookPro14,3 (BCM20703A2 on UART, hci_uart_bcm). Installs BlueZ, starts
# bluetooth.service at every boot, and installs mac-bt-pair, which pairs devices the way that
# works on this controller.
#   sudo ./install-bluetooth.sh
#
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/distro.sh
. "$REPO/../lib/distro.sh"

case "$DISTRO" in
  arch) pkg_install bluez bluez-utils ;;
  *)    pkg_install bluez ;;
esac

systemctl enable --now bluetooth.service
install -Dm755 "$REPO/bin/mac-bt-pair" /usr/local/bin/mac-bt-pair
echo "Installed /usr/local/bin/mac-bt-pair"

# the controller registers a second or two after the service starts
for _ in 1 2 3 4 5; do
  bluetoothctl list 2>/dev/null | grep -q Controller && break
  sleep 1
done
if bluetoothctl list 2>/dev/null | grep -q Controller; then
  echo "Bluetooth is up. Pair a device:  mac-bt-pair, then  mac-bt-pair <address>"
else
  echo "bluetooth.service runs, but no controller showed up. See Troubleshooting in bluetooth/README.md" >&2
  exit 1
fi
