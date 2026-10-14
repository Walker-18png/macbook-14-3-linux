#!/usr/bin/env bash
# Removes what install-kernel-updates.sh added.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
rm -f /usr/local/bin/dkms-precheck /usr/local/bin/dkms-verify \
  /etc/pacman.d/hooks/01-dkms-precheck.hook /etc/pacman.d/hooks/99-dkms-verify.hook
echo "Removed."
