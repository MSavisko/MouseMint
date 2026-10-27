# MouseMint architecture

Use a small AppKit app with clear boundaries: **UI → app coordinator → device drivers and macOS adapters**. Shared value types and policies sit underneath these parts. Keep one app target for now; folders express ownership, while protocols make hardware and system behavior replaceable in tests.

This is the direction for future changes, adopted on 2026-10-27. It builds on the existing readers, scrolling backend, injected Settings callbacks, and hostless XCTest suite. The source files have not been reorganized yet. [Research from three 2026 projects](architecture-references.md) informed this choice.

## Responsibilities

| Part | Owns | Must stay outside it |
| --- | --- | --- |
| App startup | Construct dependencies, connect callbacks, app lifecycle and diagnostic entry points | Report decoding and view layout |
| App coordinator | Refresh lifecycle, connection selection, one current snapshot, user actions, applying scrolling policy | HID byte offsets and AppKit controls |
| Shared models and policy | Device identity, transport, battery/power values, connection certainty, capabilities and selection rules | IOKit handles, views, storage and system calls |
| Device drivers | Supported identities and interfaces, model-specific commands and decoders, normalized results | UI, global scrolling changes and other drivers |
| macOS adapters and preferences | HID access, accessory battery service, system scrolling, saved settings and migration | Deciding what the UI should show |
| UI | Menu bar, Settings panes, formatting and callbacks for user intent | Polling, device commands and direct preference writes |

Startup is the place that knows the concrete implementations. A controller receives state and callbacks; the coordinator receives a reader, scheduler and system-setting interfaces. Device drivers use transport interfaces and return plain values. Shared models do not import AppKit or IOKit. These are source-level rules today, not boundaries enforced by separate compiled modules.

The existing `NaturalScrollingBackend` is a useful example: policy can be tested against a fake while `SystemNaturalScrolling` owns the macOS calls. Keep that pattern small and use it where there are real effects to replace.

## State and execution

The coordinator should publish one coherent snapshot for the menu, Settings, and diagnostics. It contains the selected device/transport, connection certainty, optional battery/power information, reading time/source, refresh state, and a typed failure when relevant. Format strings at the UI or diagnostics boundary.

Treat connection certainty and battery availability independently. A directly detected mouse can be connected while its battery is unavailable; a receiver timeout establishes neither a battery percentage nor a disconnection. A confirmed disconnect clears the displayed reading. Preserve the current transport priority: cable, connected Bluetooth, then responding receiver. Read time is not a guarantee that macOS supplied a fresh Bluetooth battery estimate.

UI state has one writer on the main thread. Keep blocking HID reads and their callback run loops on the serial worker. Timer, wake, menu-open and manual refresh requests share the same in-flight guard. If device selection or lifecycle changes during a future asynchronous read, discard results from the previous selection or generation. Stop timers and unregister callbacks before releasing their owners and buffers. A Swift concurrency migration can be a separate change; it is not required for this structure.

Scrolling policy consumes connection state and the user's automation preference. Only the macOS adapter writes the shared setting. Preserve the current rules: connected → off, disconnected → on, unknown → unchanged. A rendering refresh must never apply this policy by itself.

## Adding another mouse

Keep a small driver interface: match an endpoint, describe verified capabilities, and read a normalized status through injected transport access. Register concrete drivers at startup. A new model should need its own driver, evidence, fixtures and registration, with shared UI changes only when it introduces a new user-visible capability.

Match the model, transport, and correct HID collection. USB port numbers and display names are not device identities. VID/PID identifies a model, not an individual mouse. The current one-mouse scope stays in place until a tested identity and selection policy supports multiple devices; do not silently group identical mice or invent a persistent identifier when hardware provides none.

Capabilities describe verified support, including transport or firmware limits. Showing battery percentage does not imply support for DPI, profiles, remapping, RGB, or firmware updates. Add configuration writing through a separate interface when implementing an explicitly requested control; a status reader must remain read-only.

For each supported transport, record the request/response evidence and test both valid and malformed reports. Keep captured bytes distinguishable from synthetic cases. Unsupported hardware and missing macOS helpers produce an explicit unavailable state. Supporting a second real model is the point to review the driver interface against both implementations.

## Where code should move as it changes

These are intended ownership groups, not folders already present:

| Current code | Intended home and next separation |
| --- | --- |
| `Sources/main.swift` | Keep the entry point here; extract orchestration into `Sources/App/AppCoordinator.swift` and presentation into `Sources/UI/` |
| `BatteryStatus.swift`, `ConnectionMode.swift`, `MouseReading` | Shared values under `Sources/Domain/`; move M3 matching and byte decoding into its driver |
| `MouseReader.swift`, `ReceiverReader.swift` | M3 implementation under `Sources/Devices/KeychronM3/`; reusable HID access under `Sources/Platform/` |
| `BluetoothBatteryReader.swift` | macOS enumeration under `Sources/Platform/`; model matching and normalization owned by the driver |
| `NaturalScrolling.swift` | Pure policy under `Sources/Domain/`; native calls under `Sources/Platform/`; saved choice under `Sources/Preferences/` |
| `StatusPolling.swift`, `PreferencesMigration.swift` | Scheduling under `Sources/App/`; saved interval and migration under `Sources/Preferences/` |
| `SettingsWindow.swift`, `ModeIcon.swift` | `Sources/UI/`; keep callbacks for user actions and pass shared view state |

Extract the coordinator first when changing refresh behavior. Then separate device matching/decoding from transport I/O before adding a second model. Move files with the relevant feature or refactor, keeping behavior unchanged and tests green at each step. Update Tuist source/test globs and the persistence probe's explicit source paths when moving files; exclude `Tests/Support` from the XCTest source glob. Keep the app entry point excluded from hostless tests.

The existing app, test and persistence-probe targets remain sufficient. Consider a separate module only when another executable needs shared code or source-level rules repeatedly fail to contain dependencies. Keep macOS 13 compatibility; adopting a newer state-management API or UI framework requires a separate compatibility decision.

## Future profiles

Profiles should be plain, versioned settings values, persisted separately from live device readings. Applying a profile goes through the coordinator and validated capabilities. Do not persist transient connection state or assume different mice support the same controls. The profile UI, persistence and device writes are future feature work, not implemented by this document.

## Checks when changing a boundary

Run `mise run test` and `mise run build`. Preserve captured-report validation, connection priority, unknown/disconnected behavior, scrolling rules, migration, and the separate-process persistence check. Add a fake-backed test for new coordination behavior. Tests must not launch production polling or mutate global scrolling. Keep diagnostic modes read-only. Render affected UI and use live read-only inspection when hardware behavior changes.

The day-to-day rules and commands are in [AGENTS.md](../AGENTS.md). Keep [PLAN.md](../PLAN.md) focused on requested work; documenting this architecture does not complete the source reorganization or profile feature.
