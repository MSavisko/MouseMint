# Keychron Charge

A tiny native macOS menu bar app for the **Keychron M3-A3**, detected over a direct USB cable as **3434:D033**. No dependencies, server, driver installation, or mouse configuration changes.

## Run

Open **[dist/Keychron Charge.app](dist/Keychron%20Charge.app)** in Finder. A battery percentage appears in the menu bar. Click it for status, the last update time, manual refresh, diagnostics, and Quit. The app refreshes every 30 seconds and after waking from sleep. It does not add itself to login items.

The included build is for Apple Silicon and macOS 13 or later. It is locally ad-hoc signed, not notarized for distribution.

```sh
./build.sh
open "dist/Keychron Charge.app"
```

For a single machine-readable USB reading:

```sh
"dist/Keychron Charge.app/Contents/MacOS/KeychronCharge" --read-json
```

Run this from a normal terminal. A restricted agent terminal can list the mouse but cannot open its HID interface; it returns `0xe00002e2`. The successful live checks here required execution outside that terminal sandbox. The app itself is not App Sandbox enabled and does not require a privileged helper.

## What it displays

- **Battery percentage:** the mouse's own estimate, rather than an inferred USB power value.
- **Power state:** on battery, charging, or external power/full. The live mouse reported 100% with state `2`; it is displayed as “Fully charged.” State `1` is the charging indicator used by the official app. Unknown states remain explicitly unknown.
- **Diagnostics:** raw response bytes, USB identity, and read timestamp, copied only when requested.

The app focuses on battery percentage, as requested. The basic-status response contains no measured charging current, voltage, or watts.

Scope: direct USB **D033** only. Bluetooth, receivers, newer 4K/8K M3 variants, multiple identical mice, and charging/discharging transitions were not tested. An unavailable or malformed response shows no percentage. The app does not substitute an earlier value or assume 100%.

## Validation

```sh
./test.sh
"dist/Keychron Charge.app/Contents/MacOS/KeychronCharge" --check-ui
```

The checks cover the captured hardware response, wrong-device and wrong-command rejection, truncated/all-zero/out-of-range reports, legitimate 0%, and power-state labels. Hardware results and protocol evidence are in [docs/usb-protocol.md](docs/usb-protocol.md).

`--check-ui` runs the actual app lifecycle, reads the connected mouse, prints the menu bar label and menu contents, then exits. The live check reported `100%` and `Status: Fully charged`.

## Sources

- [Official Keychron Engine download and USB connection instructions](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software).
- [KeyTray M3 driver](https://github.com/voxors/KeyTray/blob/94b2841971c7c41d660fe5729c69b6cb2d2ee4dd/src/pkg/driver/keychronM3/keychronM3.go), which identified the matching USB model and battery fields. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Independent utility; not affiliated with Keychron.
