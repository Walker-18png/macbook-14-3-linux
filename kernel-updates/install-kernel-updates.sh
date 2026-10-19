#!/usr/bin/env bash
# Installs the DKMS guard: pacman test-builds every DKMS module against new
# linux-headers before the upgrade and aborts it on a failed build.
#   sudo ./install-kernel-updates.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
REPO="$(cd "$(dirname "$0")" && pwd)"
command -v pacman >/dev/null || { echo "These are pacman hooks, for Arch only. See README.md." >&2; exit 1; }
for c in dkms bsdtar unshare pacman-conf; do
  command -v $c >/dev/null || { echo "$c missing (pacman -S dkms libarchive util-linux pacman)" >&2; exit 1; }
done
install -Dm755 "$REPO/dkms-precheck" /usr/local/bin/dkms-precheck
install -Dm755 "$REPO/dkms-verify" /usr/local/bin/dkms-verify
install -Dm644 "$REPO/hooks/01-dkms-precheck.hook" /etc/pacman.d/hooks/01-dkms-precheck.hook
install -Dm644 "$REPO/hooks/99-dkms-verify.hook" /etc/pacman.d/hooks/99-dkms-verify.hook
echo "Installed. Test it on the current headers package:"
echo "  sudo dkms-precheck /var/cache/pacman/pkg/linux-headers-<version>-x86_64.pkg.tar.zst"
