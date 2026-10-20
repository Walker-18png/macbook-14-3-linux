# Bluetooth on the MacBookPro14,3

The Bluetooth chip is a BCM20703A2 on a serial (UART) link, driven by `hci_uart_bcm`. It works
without extra firmware, but two things get in the way:

- **The service is off.** Arch and some other distributions install BlueZ without starting
  `bluetooth.service`, so nothing finds the adapter.
- **`bluetoothctl pair` fails.** When asked to pair, the kernel requests the device's name before
  it starts the security handshake. On this controller the name never comes back while the link
  is up. The device waits 20 seconds and hangs up, and BlueZ reports `AuthenticationFailed` or
  `AuthenticationCancelled`, even with the device in pairing mode.

  A plain `connect` doesn't wait for the name. The link goes live at once, and the device pairs
  when its profiles ask for encryption. `mac-bt-pair` pairs this way.

Tested on: MacBookPro14,3, Arch Linux, kernel 7.2.11-arch1-1. AirPods Max paired, connected and
played audio (A2DP) with the connect method. The installer itself has not run on a fresh install.

## Install

```sh
sudo ./install-bluetooth.sh
```

No reboot needed.

## Pair a device

Put the device in pairing mode, then:

```sh
mac-bt-pair                      # 10 s scan, lists devices with their addresses
mac-bt-pair AA:BB:CC:DD:EE:FF    # pair, trust and connect
```

Trusted devices reconnect by themselves later. After the first pair, `bluetoothctl connect`,
desktop Bluetooth menus and the device's own controls work as usual. Only the first pair needs
`mac-bt-pair`.

Graphical Bluetooth tools pair through BlueZ's `Pair` call, the same request as
`bluetoothctl pair`, so expect their Pair button to fail the same way (not tested). Use
`mac-bt-pair` for the first pair.

## Verify

```sh
bluetoothctl show | grep -E 'Powered|Pairable'   # Powered: yes
bluetoothctl info <address> | grep -E 'Paired|Connected'
```

Headphones show up as an output in your audio settings (`pactl list sinks short | grep bluez`).

## Troubleshooting

- **`No default controller available` right after boot:** the controller registers a second or
  two after `bluetooth.service` starts. Run the command again.
- **These `dmesg` lines are expected** and don't stop Bluetooth from working:
  `BCM: firmware Patch file not found, tried: 'brcm/BCM.hcd'`,
  `BCM: failed to write update baudrate (-16)` and `Unexpected number of ACPI GPIOs: 0`. Apple
  stores the chip's firmware on the chip itself, so Linux has no patch file to load.
- **Don't load firmware from macOS.** `/usr/share/firmware/bluetooth/` on the macOS system
  volume has `20703_*.dfu` files for USB-attached chips, and `BCM20703-*.hex` files that rewrite
  the chip's flash. Neither is a Linux patch file, and a bad flash can break Bluetooth in macOS
  too.
- **A keyboard asks for a passkey:** `mac-bt-pair` doesn't type passkeys. Untested, but the
  same connect method should work by hand: in `bluetoothctl`, run `agent KeyboardDisplay`,
  `default-agent`, then `connect <address>`, and type the code it shows on the keyboard.

## Remove

```sh
sudo ./uninstall-bluetooth.sh
```

This disables `bluetooth.service` and removes `mac-bt-pair`. BlueZ and your paired devices stay.
