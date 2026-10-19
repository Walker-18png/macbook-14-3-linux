# Kernel updates

This kit runs five out-of-tree drivers through DKMS: the Touch Bar (`apple-ib-drv`), speakers
(`snd-hda-macbookpro`), `tb-lc-keep` and `acpi-bridge-bus` from [power/](../power/README.md), plus
any you add. A kernel update that one of them can't build against leaves you with no Touch Bar,
no sound or dead Thunderbolt after the reboot. These pacman hooks catch that before it happens.

They work on Arch and Arch-based distributions only. On Fedora, Ubuntu, Debian and openSUSE, DKMS
still rebuilds the modules after a kernel update, but nothing stops an update whose build fails.
Run `dkms status` after each kernel update, and boot the previous kernel from the boot menu if a
module is missing.

## Install

```sh
cd kernel-updates
sudo ./install-kernel-updates.sh
```

`sudo ./uninstall-kernel-updates.sh` removes it.

## What it does

| Hook | When | What |
|---|---|---|
| `01-dkms-precheck.hook` | Before pacman installs a new `linux-headers` | `dkms-precheck` builds every DKMS module against the new headers in a private mount namespace. Overlays catch all writes, so the real system stays untouched. One failed build aborts the whole upgrade. Takes about 30 s |
| `99-dkms-verify.hook` | After any kernel, headers or `*-dkms` package change | `dkms-verify` warns if a DKMS module is missing for an installed kernel |

On a failed build, keep the working kernel and upgrade the rest:

```sh
sudo pacman -Syu --ignore linux,linux-headers
```

Then fix the module or wait for an update, and run the full upgrade again. To skip the check once:
`sudo touch /etc/dkms-precheck.skip`.

## Scope

- The precheck triggers on the `linux-headers` package only. For `linux-zen` or `linux-lts`,
  change `Target` in `01-dkms-precheck.hook` and the package name in `dkms-precheck`.
- It reads the new headers package from pacman's cache, so it needs the package downloaded in
  the same transaction. That is how `pacman -Syu` works.

## Test

```sh
sudo dkms-precheck /var/cache/pacman/pkg/linux-headers-<version>-x86_64.pkg.tar.zst
```

It should print `ok` for each module and `all modules build`.
