# USB investigation — 2026-10-22

## Actual connected hardware

`hidutil list` and IORegistry identified:

| Property | Value |
| --- | --- |
| USB product | Keychron M3 |
| User's model designation | M3-A3 |
| Vendor ID | `0x3434` |
| Product ID | `0xD033` |
| USB device revision | `0x0123` |
| Telemetry collection | Usage page `0x008C`, usage `1` |
| Other collections | Mouse and keyboard, which the app does not open |
| Feature report 0x51 | 20-byte payload + report ID = 21 bytes |

This older M3 does not use the newer M5/8K `B3 06` protocol. No firmware was flashed, no kernel extension installed, and no mouse settings changed.

## Working exchange

1. Open the telemetry HID collection with `kIOHIDOptionsTypeNone` (shared, not exclusive).
2. Send **feature report** `0x51`, with the complete 21-byte buffer `51 06 00 00 ... 00`.
3. Read **feature report** `0x51` into a 21-byte buffer.
4. Validate the report ID, command, success byte, embedded VID/PID, length, and percentage range before displaying anything.
5. Close the HID device.

The SET_REPORT here carries the **get basic status command `0x06`**. SET_REPORT is USB transport terminology; it does not imply that the command changes a mouse setting.

The successful response from the connected mouse was:

```text
51 06 01 00 34 34 33 d0 23 01 00 64 02 00 00 00 00 00 00 00 00
```

Offsets include the report ID:

| Offset | Meaning | Captured value |
| --- | --- | --- |
| 0 | Report ID | `51` |
| 1 | Basic status command | `06` |
| 2 | Success marker | `01` |
| 4–5 | VID, little endian | `3434` |
| 6–7 | PID, little endian | `D033` |
| 8–9 | Revision, little endian | `0123` |
| 10 | Connection bit fields | `00` |
| 11 | Battery percentage | `64` hex = **100%** |
| 12 | Power state | `02` |

The official app uses power-state `1` to draw the charging icon. The live `2` at 100% is displayed as full; a state `2` below 100% is conservatively labelled external power. A physical charging/discharging transition still needs testing with this mouse below full charge.

Reading `0x51` without sending `51 06` first returned only zero bytes, despite a successful IOKit return code. This is why merely accepting an IOKit success result gives a false 0% reading. A direct `0x52` read was not a working alternative.

## Official software evidence

Downloaded **Keychron Engine 1.0.10 for macOS** from the link on [Keychron's software page](https://www.keychron.com/pages/learn-more-how-to-use-keychron-mouse-software). Expanded the package into `/tmp` and inspected the executable's exported symbols/disassembly. The package was not installed or executed.

Package SHA-256: `9660ef8b64016a5c7cdc7944d196a7be4b0698c2a5fa9077a684ff245db6d055`

Relevant x86-64 executable addresses in that exact version:

- `MainWindow::GetMouseData()` at `0x100046480`: builds `51 06`, length `0x15`, then calls `DeviceComm::SetDeviceData(..., true)`.
- `DeviceComm::SetDeviceData(...)` at `0x100038970`: sends the feature report, then gets the feature report; the wired route needs no receiver ACK.
- `MainWindow::GetDeviceBasicInfo(...)` at `0x10004a1e0`: reads percentage at `+0x0b`, power state at `+0x0c`.
- `BatteryCtrl::paintEvent(...)` at `0x1000157c0`: checks power state `1` for the charging icon.

[KeyTray's exact-model driver](https://github.com/voxors/KeyTray/blob/94b2841971c7c41d660fe5729c69b6cb2d2ee4dd/src/pkg/driver/keychronM3/keychronM3.go) independently identifies `3434:D033`, usage page 140, and the same percentage/power-state offsets. Its GET_REPORT-only approach returned zeros in this live wired test; the official app's request step resolved it.

## Limits

No electrical current, voltage, wattage, or charging-time field was found in this basic-status response. The app focuses on the battery percentage requested by the user; it does not infer current from USB descriptors or the battery's advertised capacity.

The decoder tests use synthetic checks plus the actual captured response. They do not establish accuracy of the mouse's percentage estimate or untested transports. The final app's `--read-json` command successfully read the same 100% status from the connected mouse. LaunchServices accepted the app launch; visual inspection through the computer-use tool timed out. A subsequent `--check-ui` run exercised the real NSApplication lifecycle and asynchronous USB read, confirming the actual status button title was `100%` and the built NSMenu contained `Battery: 100%` and `Status: Fully charged`. This verifies data flow into native UI components, but is not a screenshot-based layout inspection.

## Receiver and Bluetooth support — 2026-10-22

The USB-C receiver enumerated as **Keychron Link `3434:D031`**. The direct mouse remained `3434:D033` when moved to another MacBook USB port. Port/location IDs are deliberately not used to identify the mouse.

### USB-C receiver

The D031 receiver did not provide a working `GET_REPORT 0x51` response to the wired `51 06` sequence. The official Engine's `MainWindow::SetRF24GNotifyData()` at `0x100046260` sends the 21-byte feature command `51 0c 02 00 ... 00`, which requests wireless status notifications. Registering the input callback **before** sending that request produced fresh 21-byte input reports:

```text
54 e4 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
54 e3 00 03 00 62 00 07 31 2e 32 2e 33 72 00 00 00 00 00 00 00
```

The E4 packet acknowledges the request. The E3 packet contains a status/result, link state, power state at offset 4, battery at offset 5 (`62` = 98%), and a NUL-terminated firmware string at offset 8 (`1.2.3r`), with its length including the terminator at offset 7. Subsequent captures reported 100% after the mouse had charged over its cable. The decoder accepts only the complete observed frame shape, expected header/status/link markers, 0–100%, recognized power states, and a bounded printable firmware string with its terminating NUL.

When the mouse was switched to wired mode, the still-plugged receiver instead returned:

```text
54 e4 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

It sent no E3 mouse battery packet. The app treats that as unavailable and never reuses its previous wireless percentage. The receiver handler opens only the telemetry collection, handles callbacks on its worker run loop, and unregisters/unschedules before releasing the input buffer. A missing reply times out after 1.2 seconds. It does not change pairing, DPI, button mappings, or firmware.

### Bluetooth LE

After the user switched to Bluetooth and verified pointer movement, `hidutil list` showed **Keychron M3 `3434:D033`**, transport **Bluetooth Low Energy**, usage page 1 / usage 2. Its HID report descriptor has no battery field, but macOS already publishes a battery entry. Both `system_profiler SPBluetoothDataType` and `pmset -g accps` reported **100%**; the firmware was **1.2.3r**, matching the receiver status packet.

The native app reads that same accessory power source using `IOPSCopyPowerSourcesByType(4)`, followed by `IOPSCopyPowerSourcesList` and `IOPSGetPowerSourceDescription`. Apple declares value 4 as `kIOPSSourceForAccessories` in [IOPowerSourcesPrivate.h](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ps.subproj/IOPowerSourcesPrivate.h). This is unsupported SPI; the function is found with `dlsym` and its absence produces an unavailable percentage rather than a launch failure.

The matching battery entry contained:

```text
Accessory Category = Mouse
Current Capacity = 100
Max Capacity = 100
Name = Keychron M3
Power Source State = Battery Power
Product ID = 53299 (D033)
Transport Type = Bluetooth LE
Vendor ID = 13364 (3434)
```

Only those device-specific fields are read. The app requires a currently enumerated M3 Bluetooth HID mouse before using this battery entry, so an old accessory record or plugged-in dongle cannot falsely select Bluetooth mode. The app does not initiate a Bluetooth scan, connection, or pairing operation.

### Live validation

- **Cable with receiver still attached, different cable port:** native UI showed `Connection: USB cable`, `Battery: 99%`, `Status: Charging`.
- **Bluetooth with receiver still attached:** final native UI showed `Mode icon: Bluetooth`, `Connection: Bluetooth`, `Battery: 100%`, `Status: On battery`.
- **Back to receiver, cable unplugged:** final executable read `mode: receiver`, PID D031, fresh E3 packet with `percentage: 100`, `powerState: 0`. Native UI check confirmed `Mode icon: 2.4 GHz receiver`, `Battery: 100%`, and `Status: On battery`.

Selection order is cable, connected Bluetooth mouse, responding receiver. Tests cover the mode identity and priority rules, malformed USB/receiver packets, unrelated Bluetooth battery entries, missing/invalid capacities, and legitimate 0%. The earlier computer-use tool timed out; native UI verification therefore inspects the real NSStatusItem/NSMenu state instead of claiming a screenshot-based visual check. Physical transitions and mouse identity were cross-checked through HID enumeration and the user's pointer tests.
