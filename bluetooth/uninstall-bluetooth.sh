#!/usr/bin/env bash
#
# Removes mac-bt-pair and stops bluetooth.service from starting at boot. BlueZ and your paired
# devices stay.
#   sudo ./uninstall-bluetooth.sh
#
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }

rm -f /usr/local/bin/mac-bt-pair
systemctl disable --now bluetooth.service
echo "Removed mac-bt-pair and disabled bluetooth.service"
