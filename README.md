# Keychron Charge

A tiny native macOS menu bar app for the **Keychron M3-A3**. It displays battery percentage and the active connection mode: **USB cable, USB-C 2.4 GHz receiver, or Bluetooth**.

## Run

Open **[dist/Keychron Charge.app](dist/Keychron%20Charge.app)** in Finder. Click the menu bar icon for connection mode, battery percentage, charging status, manual refresh, and diagnostics.

The icon changes with the connection: cable connector, USB receiver, or Bluetooth rune. The app checks every five seconds and after waking from sleep. It gives a cable connection priority, then a connected Bluetooth mouse, then a responding wireless receiver. An idle receiver alone does not count as an active mouse connection. No USB port is hard-coded.

The included build is for Apple Silicon and macOS 13 or later. It is locally ad-hoc signed, not notarized for distribution. It does not add itself to login items, use a network service, install a driver, or change mouse configuration.

```sh
./build.sh
open "dist/Keychron Charge.app"
```

## Battery sources

| Connection | Supported device | Battery source |
| --- | --- | --- |
| USB cable | `3434:D033` | Mouse basic-status feature report |
| USB-C receiver | Keychron Link `3434:D031` | Fresh mouse status event through the receiver |
| Bluetooth LE | M3 `3434:D033` | macOS accessory battery service |

The percentage is the value reported by the mouse or macOS. Different transports may briefly show different estimates, particularly after charging. The app does not smooth them or reuse a percentage from a disconnected transport. The displayed update time is when the app read the data; macOS controls the freshness of Bluetooth battery data.

Bluetooth uses the connected mouse's HID identity to establish that it is connected, then matches the macOS battery entry by VID/PID, transport, and mouse category. It does not scan for or pair Bluetooth devices and requires no new Bluetooth permission. Its battery enumeration uses an unsupported IOKit helper resolved dynamically. If that helper or the battery entry is unavailable, the Bluetooth icon still appears and the percentage is shown as unavailable.

Scope: this M3-A3, its D031 USB-C receiver, and one mouse at a time. USB-A D030 receivers, newer 4K/8K M3 variants, and multiple identical mice are not supported by this build. The status report contains no measured current, voltage, or wattage.

## Validation and diagnostics

```sh
./test.sh
"dist/Keychron Charge.app/Contents/MacOS/KeychronCharge" --read-json
"dist/Keychron Charge.app/Contents/MacOS/KeychronCharge" --check-ui
```

`--read-json` returns one reading. `--check-ui` runs the native app lifecycle, reads the mouse, prints the actual status button's title, icon description, and menu contents, then exits. Run USB checks from a normal terminal; a restricted agent terminal can enumerate devices but cannot open their HID interfaces.

The tests cover captured reports, malformed and unrelated responses, valid 0%, charging state, Bluetooth battery validation, transport identity, and connection priority. Live tests verified cable mode in a different USB port with the receiver attached, Bluetooth with the receiver attached, and 2.4 GHz receiver mode. See [protocol evidence](docs/usb-protocol.md) for captures and limitations.

## Sources

- [Official Keychron Engine and connection instructions](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software).
- [KeyTray M3 driver](https://github.com/voxors/KeyTray/blob/94b2841971c7c41d660fe5729c69b6cb2d2ee4dd/src/pkg/driver/keychronM3/keychronM3.go). See [third-party notices](THIRD_PARTY_NOTICES.md).
- [Apple IOKit accessory power-source declarations](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ps.subproj/IOPowerSourcesPrivate.h).

Independent utility; not affiliated with Keychron.
