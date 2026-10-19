# Speakers on the MacBookPro14,3

The T1 MacBook Pro uses a Cirrus CS8409 codec. The stock kernel module has no Apple quirk for this
machine, so the internal speakers stay silent. This installs the community driver
`snd-hda-macbookpro` (GPL-2.0, [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro))
as a DKMS module. On Arch it comes from the AUR. On Fedora, Ubuntu, Debian and openSUSE the script
clones upstream to `/usr/local/src/snd_hda_macbookpro` and runs upstream's own DKMS installer. Only
the Arch path is tested.

Tested on: MacBookPro14,3, Arch Linux, kernel 7.2.9-arch1-1. Speakers confirmed working.

## Install

```sh
./install-audio.sh
sudo reboot
```

Run the script as your normal user. It asks for sudo itself. On Arch it needs `yay`.

The package is `snd-hda-macbookpro-dkms-git` from the AUR. It builds the latest upstream commit, so
yay shows the PKGBUILD before it builds: read it, and check the source URL points at
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro).

On other distributions the script prints the upstream commit and waits for a yes. Read
`install.cirrus.driver.sh` and `dkms.sh` in the clone before you answer: both run as root. Upstream's
DKMS build downloads the matching kernel source from kernel.org for every new kernel, so kernel
updates need a network connection.

## Before you install: EFI partition space

The driver's initrd step writes into the EFI system partition. On this machine the ESP is 300 MB and
was 97% full, and the install failed with `No space left on device`. Check first:

```sh
df -h /efi          # or /boot/efi
ls -la /efi/*/*/    # look for large initrd-fallback files
```

Deleting `initrd-fallback` frees about 118 MB. Its boot entry only uses the main `initrd`. Do not delete the
main `initrd` or `linux` files, and do not touch `EFI/APPLE/EMBEDDEDOS/combined.memboot` (the T1 firmware).

## Verify

```sh
dmesg | grep -i cs8409
```

- `Primary patch_cs8409 NOT FOUND trying APPLE` followed by `autoconfig for CS8409` means the driver loaded.
- `UNKNOWN subsystem id 0x10138409` means the firmware boot data is corrupt. This is a known Apple NVRAM problem
  (see [issue #80](https://github.com/davidjo/snd_hda_macbookpro/issues/80)). Reset the NVRAM with
  Cmd+Opt+P+R at power-on, boot Linux, then reinstall GRUB. Issue
  [#134](https://github.com/davidjo/snd_hda_macbookpro/issues/134#issuecomment-2426011312) reports that this makes the fix stick:
  `sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB && sudo grub-mkconfig -o /boot/grub/grub.cfg`
  (adjust the ESP path to your system).

Pick the default output in your audio mixer if the speakers are not selected. Known open issue on this model:
weak bass ([issue #213](https://github.com/davidjo/snd_hda_macbookpro/issues/213)).

## Remove

```sh
# Arch
yay -R snd-hda-macbookpro-dkms-git

# Other distributions
cd /usr/local/src/snd_hda_macbookpro && sudo ./install.cirrus.driver.sh -r
sudo rm -rf /usr/local/src/snd_hda_macbookpro

sudo reboot
```
