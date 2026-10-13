# Wi-Fi on the MacBookPro14,3

The BCM43602 card runs with a board NVRAM file that is missing for this model. Without it,
`brcmfmac` only sees 2.4 GHz networks. The file in this folder adds the board data and sets
the regulatory fields to defer to the host's regulatory domain (`ccode=00`, `regrev=245`).

Tested on: MacBookPro14,3, Arch Linux, kernel 7.2.9-arch1-1. The Mac associates with a 5 GHz network
after the install.

## Install

```sh
sudo ./install-wifi.sh
sudo reboot
```

The file is installed under `/usr/lib/firmware/updates/brcm/`, which the kernel reads ahead of the stock
firmware directory.

## Notes

- `macaddr=00:90:4c:0d:f4:3e` is Broadcom's placeholder. The card uses its own MAC address. Do not copy
  a real device address into this file.
- Set the band on your network with NetworkManager if your router offers both bands:
  `nmcli con modify <name> 802-11-wireless.band a`.

## Remove

```sh
sudo rm /usr/lib/firmware/updates/brcm/brcmfmac43602-pcie.txt
sudo reboot
```
