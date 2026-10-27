# MouseMint architecture

Use a small AppKit app with clear boundaries: **UI → app coordinator → device drivers and macOS adapters**. Shared value types and policies sit underneath these parts. Keep one app target for now; folders express ownership, while protocols make hardware and system behavior replaceable in tests.

This structure was implemented on 2026-10-27 through the approved test-first refactoring plan. The original reports, user-facing behavior, settings migration, and hostless test setup are retained. [Research from three 2026 projects](architecture-references.md) informed this choice.

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

`ScrollingPolicy` returns a desired setting without performing effects. `AutomaticNaturalScrolling` in App coordinates saved choices and the `NaturalScrollingBackend`; `SystemNaturalScrolling` in Platform owns native calls. Tests cover the pure decision and application effects separately.

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

## Current layout

| Location | Implementation |
| --- | --- |
| `Sources/main.swift` | Thin command entry point |
| `Sources/App/` | `AppComposition`, `AppCoordinator`, `CommandRunner`, native lifecycle bridge, scheduling, driver selection and scrolling effect orchestration |
| `Sources/Domain/` | Shared snapshots, readings, transport/connection types, small effect contracts and pure scrolling/interval policy; no native calls or storage |
| `Sources/Devices/KeychronM3/` | M3 identity, verified capabilities, report decoding, requests, retries and response handling |
| `Sources/Platform/` | HID discovery/session access, accessory power service and native scrolling operations |
| `Sources/Preferences/` | Saved scrolling choice, interval and one-time legacy migration |
| `Sources/UI/` | Menu rendering, Settings, icons, diagnostic reports and display/error formatting |
| `Tests/` | App, Domain, Devices, Platform, Preferences, UI and Integration tests; Helpers holds shared test utilities |
| `Tests/Support/` | Separate-process preferences executable, excluded from XCTest sources |

Tuist includes sources and tests recursively. Keep `Sources/main.swift` and `Tests/Support/**` out of hostless test sources, and update the persistence probe's explicit inputs when changing preferences or their contracts. The Settings renderer locates the project root independently of its file's folder depth.

The app, test and persistence-probe targets remain sufficient. A standalone compilation of `Sources/Domain/*.swift` verifies its independence from AppKit and platform implementations. Consider another module only when an additional executable needs shared code or source-level boundaries repeatedly fail. Keep macOS 13 compatibility; adopting newer observation APIs or another UI framework requires a separate compatibility decision.

## Future profiles

Profiles should be plain, versioned settings values, persisted separately from live device readings. Applying a profile goes through the coordinator and validated capabilities. Do not persist transient connection state or assume different mice support the same controls. The profile UI, persistence and device writes are future feature work, not implemented by this document.

## Checks when changing a boundary

Run `mise run test` and `mise run build`. Preserve captured-report validation, connection priority, unknown/disconnected behavior, scrolling rules, migration, and the separate-process persistence check. Add a fake-backed test for new coordination behavior. Tests must not launch production polling or mutate global scrolling. Keep diagnostic modes read-only. Render affected UI and use live read-only inspection when hardware behavior changes.

The day-to-day rules and commands are in [AGENTS.md](../AGENTS.md). Keep [PLAN.md](../PLAN.md) focused on requested work; the completed source reorganization does not implement profiles or another mouse. The [validation record](refactoring-validation.md) distinguishes automated coverage from live hardware checks.
