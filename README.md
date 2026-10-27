# MouseMint

Mouse battery and scrolling controls for macOS. Supports the **Keychron M3-A3** over **USB cable, USB-C 2.4 GHz receiver, and Bluetooth**.

**Keychron Engine is not required or used by this app.** MouseMint communicates directly with the mouse/receiver through macOS IOKit and reads Bluetooth battery information from macOS. It works without Engine installed or running.

## Run

Build the app using the commands below, then open **MouseMint.app** in the `dist` folder. Click the menu bar icon for connection mode, battery percentage, charging status, and the current Natural Scrolling state. Open **Settings…** for controls and utilities.

The dropdown contains status information, Settings, and Quit, with native monochrome macOS symbols and the matching connection-mode icon. Utility actions and detailed errors live in Settings.

The icon changes with the connection: cable connector, USB receiver, or Bluetooth rune. The app checks at your chosen interval (five seconds by default), after waking from sleep, and when opening the menu. It gives a cable connection priority, then a connected Bluetooth mouse, then a responding wireless receiver. An idle receiver alone does not count as an active mouse connection. No USB port is hard-coded.

When the mouse is disconnected or its receiver reports no connected mouse, the menu bar shows a circled X and **Not connected**. The menu suggests waking the mouse or checking its connection. Receiver timeouts, USB access failures, and read errors are labelled separately as **Read error**.

Building requires an Apple Silicon Mac, **Xcode 27.1**, and **mise 2026.6.10 or later**. Select Xcode 27.1 as your active developer tools; Command Line Tools alone are not enough. The app runs on macOS 13 or later. It is locally ad-hoc signed, not notarized for distribution.

```sh
git clone https://github.com/MSavisko/MouseMint.git
cd MouseMint
brew install mise
mise trust
mise install --locked
mise run build
open "dist/MouseMint.app"
```

Tuist **4.211.0** is pinned in `mise.toml`, with its download and checksum recorded in `mise.lock`. Swift and the macOS SDK come from the Xcode version checked by `Tuist.swift`. There are no third-party Swift package dependencies.

To work in Xcode, run `mise run generate` and open `MouseMint.xcworkspace`. Edit `Project.swift` for project changes; the workspace and project are generated and stay out of Git. `build.sh` and `test.sh` remain shortcuts to the same pinned build tools.

The app does not add itself to login items, use a network service, install a driver, or change mouse configuration.

Upgrading from Keychron Charge: MouseMint carries over your automatic scrolling and status-check interval settings on its first normal launch. Quit the old app before opening MouseMint.

## Automatic Natural Scrolling

Settings uses the native macOS preferences toolbar to switch between **General**, **Natural Scrolling**, **Diagnostics**, and **About** panes. The toolbar is not customizable and always identifies the selected pane, following [Apple's settings-window guidance](https://developer.apple.com/design/human-interface-guidelines/settings). **General** has a slider for **2, 3, 5, 8, or 10 seconds** between periodic status checks. Changes replace the active timer and are saved across launches; the default remains 5 seconds. This controls battery/connection checks and scrolling automation, not the mouse's hardware movement report rate. Faster Bluetooth checks cannot force fresher macOS battery data.

Diagnostics contains a selectable, read-only report, **Refresh Now**, and **Copy Diagnostics** with confirmation. The report updates as the app polls and includes connection, battery, raw mouse report (or Bluetooth source), app/macOS versions, status interval, scrolling values, and errors. About contains the app version and short description.

While the app is running, it turns macOS **Natural Scrolling off when the M3 is connected** and **on when it disconnects**. This is the shared macOS setting, so it also changes trackpad scrolling. Cable, receiver, and Bluetooth connections all use the same rule. The menu shows the current setting.

Open **Settings… → Natural Scrolling** to control this behavior. Turn off **Automatically switch Natural Scrolling** to stop syncing with the mouse connection. Turning it off keeps the current macOS setting; you can then change **Natural Scrolling** in this pane or in macOS Settings. Your automatic-switching choice is saved across launches. It starts enabled to preserve the existing behavior. The pane includes short explanations and the connection rule.

Connection checks use the interval chosen in General. A receiver reporting no connected mouse counts as disconnected even if the receiver remains plugged in. A timeout or battery-read error does not establish a disconnection: the app keeps the scrolling setting unchanged. A directly enumerated cable/Bluetooth mouse still counts as connected if its battery read fails.

The app applies changes immediately and saves the preference, only writing when the requested state differs. While automatic switching is enabled, it will reapply its rule if you change Natural Scrolling manually. Re-enabling automation requests a fresh connection check. Quitting stops automation and leaves the last setting in place. The implementation uses a native, unsupported macOS helper; a missing helper or failed change is reported in the menu and Settings window. See [implementation and validation](docs/natural-scrolling.md).

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
mise run test
"dist/MouseMint.app/Contents/MacOS/MouseMint" --read-json
"dist/MouseMint.app/Contents/MacOS/MouseMint" --check-ui
"dist/MouseMint.app/Contents/MacOS/MouseMint" --check-ui --settings
"dist/MouseMint.app/Contents/MacOS/MouseMint" --scroll-status
```

`--read-json` returns one reading. `--check-ui` runs the native app lifecycle, reads the mouse, prints the actual status button's title, icon description, and menu contents, then exits. Add `--settings` to also inspect the Settings toolbar panes, scrolling switches, diagnostics actions, and current report. Run USB checks from a normal terminal; a restricted agent terminal can enumerate devices but cannot open their HID interfaces.

`--scroll-status` returns the saved preference and native scrolling state. All three diagnostic commands are read-only and do not run the scrolling automation.

The native XCTest suite covers captured reports, malformed and unrelated responses, valid 0%, charging state, Bluetooth battery validation, transport identity, connection priority, scrolling behavior, settings migration, and native Settings controls. A separate helper checks that preferences survive across processes. Tests run without launching mouse polling or changing system scrolling, and render Settings previews into `.build`. Live tests verified cable mode in a different USB port with the receiver attached, Bluetooth with the receiver attached, and 2.4 GHz receiver mode. See [protocol evidence](docs/usb-protocol.md) for captures and limitations.

## Sources

Keychron Engine 1.0.10 for macOS was inspected only as a protocol research reference. It was neither installed nor executed during the investigation, and MouseMint does not bundle, launch, or depend on it. See the [protocol investigation](docs/usb-protocol.md#official-software-evidence).

See the [M3-A3 capability inventory](docs/m3-a3-capabilities.md) for vendor-documented controls, read-only configuration evidence, firmware/transport limits, and the status-interval research. No vendor minimum for battery-status queries was found; 2 seconds is an app choice, not a Keychron recommendation.

- [Official Keychron Engine and connection instructions](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software).
- [KeyTray M3 driver](https://github.com/voxors/KeyTray/blob/94b2841971c7c41d660fe5729c69b6cb2d2ee4dd/src/pkg/driver/keychronM3/keychronM3.go). See [third-party notices](THIRD_PARTY_NOTICES.md).
- [Apple IOKit accessory power-source declarations](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ps.subproj/IOPowerSourcesPrivate.h).

Independent utility; not affiliated with Keychron.

Future ideas and implementation milestones are tracked in [PLAN.md](PLAN.md).

## Development

Follow [AGENTS.md](AGENTS.md) for project rules and checks. The [architecture guide](docs/architecture.md) describes responsibilities, device support, and how to separate the existing code gradually. See the [2026 app references](docs/architecture-references.md) for the source examples behind that choice.

## License

[MIT](LICENSE) © 2026 Maksym Savisko. See [third-party notices](THIRD_PARTY_NOTICES.md) for research credits and their license.
