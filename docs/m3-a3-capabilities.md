# Keychron M3-A3: information and controls

Research checked 2026-10-23. Scope: the user's older **M3-A3, PixArt 3395 / 1K / RGB**, wired mouse `3434:D033`, and USB-C receiver `3434:D031`. The official regional [M3-A3 listing](https://www.keychron.co.th/products/keychron-m3-wireless-mouse) identifies this SKU as the 1K 3395 version. The current global M3 page covers several generations; its 4K/8K features must not be assumed to work on this mouse.

This is a comprehensive inventory of the information and operations found in the manual, vendor software, and local captures. It is not a claim that every undocumented firmware command has been discovered or that every vendor feature is already implemented in this app. Configuration changes below were researched, not applied to the mouse.

## Status interval: vendor guidance and app behavior

No minimum battery/status-query interval was found in the reviewed [M3 manual](https://www.keychron.com/pages/keychron-m3-user-manual), [Engine documentation](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software), or M3 product information. Keychron's 125/500/1000 Hz numbers describe **movement report frequency**, not how often a utility should ask for battery status. They cannot be used as a recommendation for status requests.

The app offers **2, 3, 5, 8, and 10 seconds** in **Settings → General**, keeping **5 seconds** as its default. Two seconds is an app-selected lower bound, not a vendor recommendation. It exceeds the receiver reader's 1.2-second timeout. The existing in-flight-read guard prevents concurrent requests; this does not establish a measured battery-life cost or firmware guarantee. Longer intervals make fewer requests and increase connection-change detection delay. Bluetooth checks read macOS's existing battery record; faster queries cannot force the mouse or macOS to publish fresher battery data.

The choice is saved across launches and replaces the running timer when changed. Menu opening, wake, and Diagnostics → Refresh Now can also trigger checks, so the slider controls the periodic timer, not a strict minimum gap between every possible read. The same cadence drives connection-based Natural Scrolling. No mouse DPI, USB movement report rate, or firmware setting is changed by this slider.

## Information we can receive

| Information | Evidence and transport | App status |
| --- | --- | --- |
| Battery percentage | Verified wired basic-status response, receiver status event, and macOS Bluetooth accessory record | Displayed |
| On battery / charging / full or external power | Verified cable and receiver power-state bytes; macOS Bluetooth may supply only percentage | Displayed when available; full vs external power depends on percentage |
| Active cable / 2.4 GHz / Bluetooth connection | HID enumeration and responsive receiver, verified in live transitions | Displayed |
| Confirmed receiver has no mouse | Exact captured receiver no-target acknowledgement; timeouts remain uncertain | Used for disconnection and scrolling policy |
| Vendor/product IDs, HID transport and usage, device revision | Device enumeration and wired status packet | Used internally; product ID and transport in diagnostics |
| Mouse firmware version | Earlier receiver event contained `1.2.3r`; Bluetooth system information agreed | Present in receiver raw packet; no separate firmware-version UI |
| Separate receiver firmware version | Vendor updater has a version-read operation; Engine includes a device-version reader | Not implemented or verified by this app; do not label the mouse's `1.2.3r` as receiver firmware |
| Basic configuration / DPI stages / sensor and response parameters | Official Engine's `GetMouseData()` reads command `0x07`, parsed by `GetMouseBasicInfo()`; one read succeeded on this exact wired device | Raw capture below; needs validated field decoders before UI exposure |
| Hardware movement report-rate setting | Engine has its own readback/configuration path and rate setter; vendor manual specifies 125/500/1000 Hz for 1K hardware | Not displayed; independent of the app interval |
| Button bindings and macro assignments/names | Engine has device all-key/individual-key and macro-name read paths | Not implemented; exact payloads and bounds need testing |
| Complete macro event sequences | Engine supports macros but also constructs macro payloads from its host database | Device-to-host retrieval of full sequences is not established by the inspected functions |
| RGB configuration | Engine's lighting reader and parser exist | Not implemented |
| Profiles and selected configuration metadata | Vendor tools expose profiles; Engine parses profile-related data | Exact on-device count and persistence unverified on this firmware; see limitations below |
| Motion deltas, wheel movement, button transitions | Standard mouse HID input collection, separate from the telemetry collection used here | Potential input-monitoring feature; not collected by the app |
| Read time, protocol error, raw status bytes, current macOS scroll value | Generated or read by this app rather than battery sensor measurements | Diagnostics |

For battery/mode/firmware captures and byte validation, see [USB and transport evidence](usb-protocol.md). Enumerated serial numbers would be readable only if the device actually publishes them; no stable unique serial number was established for this mouse.

### New read-only basic-configuration capture

On 2026-10-23, a temporary probe sent only the official Engine's **read basic configuration** request `51 07 00 ... 00` through the wired D033 telemetry collection, then read feature report 0x51. IOKit returned success and 21 bytes:

```text
51 07 00 03 03 03 90 01 20 03 40 06 80 0c 88 13 35 05 08 00 00
```

The Engine parser reads five little-endian words at offsets 6, 8, 10, 12, and 14. Here they are **400, 800, 1600, 3200, 5000**, consistent with configured DPI stages. Active-stage selection and the remaining flag fields have not been independently validated. This raw response is evidence that additional configuration can be read; it is not yet a production decoder. No setting command was sent.

## Controls available in vendor tools or hardware

The [official Engine guide](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software) documents button remapping, keyboard shortcuts, keyboard/mouse macros, DPI, report rate, RGB customization, lift-off distance, movement correction, and button-response latency. These are available areas for future development, not features silently added to MouseMint.

| Area | Operations found | Exact-device caveat |
| --- | --- | --- |
| Sensitivity | Set DPI levels and select a stage | 3395 1K range is 100–26,000 DPI; validate level count and step increments against readback before implementing |
| Movement report rate | Set 125, 500, or 1000 Hz for wired/2.4 GHz; hardware button cycles rates | Bluetooth uses a different path; do not advertise 4K/8K for M3-A3 |
| Lift-off distance | Choose how far the sensor tracks above the surface | Vendor 3395 specs list 1 or 2 mm |
| Sensor processing | Ripple suppression, angle snapping, motion synchronization | Present in Engine's sensor UI; exact bit meanings and firmware-dependent availability need validation on D033 |
| Click filtering | Adjust debounce/button-response delay | Supported by Engine; do not infer the allowed numeric range from newer mice |
| Button remapping | Mouse actions, keyboard combinations, shortcuts, disabled/remapped actions | Preserve a usable primary click; exact binding encodings unverified here |
| Macros | Create/edit/send sequences of mouse/keyboard actions, timing, and assigned names | Full device-to-host event readback, length limits, repeat modes, and storage need verification |
| Lighting | Choose effects and colors; adjust effect parameters | M3-A3 has RGB; brightness/speed/direction availability depends on effect and firmware |
| Pairing controls | Enter Bluetooth/receiver pairing using physical buttons; Engine contains a pairing-combination setting | The app does not initiate pairing or change pairing keys |
| Profiles | Vendor configuration/profile management | Current Launcher marketing mentions five onboard profiles, but that count is not independently proven on this installed firmware; Engine also stores host-side profile records |
| Reset | Restore configuration or factory defaults | Destructive to configuration; researched only |
| Firmware service | Read versions and update mouse/receiver firmware using vendor tools | Separate device/receiver images and procedures; not implemented and no update performed |

Ranges and physical behavior above come from the [original 1K manual](https://cdn.shopify.com/s/files/1/0059/0630/1017/files/Keychron-M3-User-Manual.pdf?v=1675131026) and [M3 comparison/specifications](https://www.keychron.com/products/keychron-m3-wireless-mouse). The manual also describes an idle sleep behavior in wireless modes; it does not establish a supported writable sleep-time field for this firmware. Do not promise an adjustable sleep timeout merely because other Keychron models expose one.

### Official-software implementation evidence

The local investigation inspected, without installing or running, Keychron Engine **1.0.10 for macOS**, downloaded via the [vendor software page](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software). Its package SHA-256 and original battery investigation are recorded in [usb-protocol.md](usb-protocol.md). The following are function/command observations in its older mouse path, not public protocol documentation or a validated write API:

| Engine method / address | Observation |
| --- | --- |
| `GetMouseData`, `0x100046480` | Reads `0x06` basic status and `0x07` basic configuration |
| `GetMouseBasicInfo`, `0x10004a830` | Parses profile/configuration fields, five 16-bit values, and sensor/response fields |
| `SetRF24GNotifyData`, `0x100046260` | Requests receiver notifications with `0x0c` |
| `SetMouseDPIData`, `0x1000483f0` | DPI-setting path, command `0x40` |
| `SetMouseReportRateData`, `0x100048b70` | Movement rate-setting path, command `0x41` |
| `SetMouseSensorLiftData`, `0x100048df0` | Sensor/LOD-setting path, command `0x42` |
| `SetButtonRespondtimeData`, `0x1000493e0` | Button-response-setting path, command `0x43` |
| `SetMouseKeyPairData`, `0x100049640` | Pairing-combination setting path, command `0x46` |
| `GetMouseAllKeysData`, `0x100050fb0`; `GetMouseAllKeysData2`, `0x10004e220` | Key-map readers |
| `GetMouseMacroData`, `0x100052160` | Reads Engine's host database to construct a macro payload; not proof of device readback |
| `GetMouseKeyMacroName`, `0x100052810` | Device macro-name read path |
| `GetMouseLightData`, `0x100054280` | Lighting read command `0x12` |
| `SetLightModeData`, `0x1000477f0` | Lighting-related commands `0x22`, `0x23`, `0x27`, `0x28` |
| `SetMouseRestoreFactoryData`, `0x100049990` | Reset-related command `0x0b`; not sent |
| `GetDeviceVersionInfo`, `0x1000545a0` | Version-reading path; transport/response validation still needed |

A useful warning against relying on function names alone: `SetMouseProfileData(int)` at `0x100046470` immediately returns zero in this executable. Its existence is not proof of working hardware profile switching. Engine's shared UI strings also include wheel-direction reversal, left-click lock, and Windows pointer speed, acceleration, wheel speed, and double-click speed. These are additional UI candidates, not verified D033 firmware controls. Windows system controls are not portable mouse settings. A lighting-sleep field in the host database also does not establish a writable mouse idle-sleep timeout.

## Transport and firmware limits

- **USB cable:** working status and basic-configuration reads were verified on D033. This is the clearest starting point for further readback work.
- **2.4 GHz receiver:** battery notifications were verified on D031. Other operations may need a receiver-specific route; do not assume the wired request/read exchange works unchanged.
- **Bluetooth:** battery is available through macOS. Engine's guide requires USB/2.4 GHz for configuration. Button actions configured elsewhere may still operate over Bluetooth; that does not prove configuration can be written over Bluetooth.
- **Launcher:** current [vendor firmware notes](https://www.keychron.com/pages/how-to-flash-the-firmware-and-factory-reset-the-keychron-wireless-mice) describe Launcher support and battery/wireless fixes for the 1K 3395 M3. They list 1.2.5r, while earlier local captures reported 1.2.3r. The firmware string alone does not identify every sub-build. Compatibility should be checked before relying on a newer Launcher's feature set. No firmware change is required for the interval slider.

## Data not established by the available evidence

No usable measurement of instantaneous charging current, battery voltage, watts, battery temperature, battery health/cycle count, remaining-time prediction, lifetime click counter, or RF signal strength was established in the observed status/configuration replies. USB power ratings and the manual's charging limits describe ratings, not live telemetry. A battery history could support approximate discharge/charge trends, but the mouse's percentage quantization and freshness would limit those estimates.

4K/8K movement rates, the 8K-only FPS/20K sensor mode, and glass tracking are not features of this 1K 3395 model. Keychron's [sensor-settings explanation](https://help-center.keychron.com/en-us/article/38042297710103-mouse-settings-explained-what-ripple-control-angle-snap-motion-sync-an) specifically ties FPS/20K to 8K hardware.

For a next implementation, the strongest evidence supports exposing firmware/identity already present in existing responses, then validating read-only DPI/rate/sensor configuration before adding reversible setters with readback. That is a development proposal, not additional work included in the interval-slider change.
