# Working on MouseMint

MouseMint is a native AppKit menu bar app for mouse battery status and scrolling controls. Read [the architecture guide](docs/architecture.md) before changing responsibilities or adding device support. The code is organized under `Sources/App`, `Domain`, `Devices`, `Platform`, `Preferences`, and `UI`; tests mirror those responsibilities.

## Build and check

Use the versions declared in `mise.toml`, `mise.lock`, and `Tuist.swift`:

```sh
mise install --locked
mise run generate
mise run test
mise run build
```

`Project.swift` owns the Xcode targets, source lists, resources, and settings. Do not hand-edit or commit generated `.xcodeproj`, `.xcworkspace`, `Derived`, `.build`, or `dist` output. Keep the app's macOS 13 deployment target and Swift 5 language mode unless the task changes them. Release automation and signing requirements are in [docs/releases.md](docs/releases.md). Never commit or log private signing keys or notarization credentials. Pin new development tools through mise; add Swift packages only for a concrete need, with exact versions and their resolver lockfile.

## Code rules

- Keep AppKit views and controllers focused on presentation and user actions. Device reads, persistence, and scrolling policy belong outside UI code.
- Compose concrete dependencies at startup. Pass small protocols or closures into code that needs hardware, system settings, a clock, or scheduling. Add an abstraction when it creates a useful boundary or enables a meaningful test.
- Keep shared device state and policies independent of AppKit and IOKit. Model-specific identity checks, report layouts, and commands belong to that device's driver. Drivers do not call each other.
- Keep UI and published app state on the main thread. Perform blocking HID work on the existing serial worker. Allow one refresh at a time; do not pass live HID handles to UI code. Make callback, buffer, timer, and device lifetimes explicit.
- Represent connected, disconnected, and unknown separately. Unavailable battery data is not 0%. A receiver being present does not prove its mouse is connected. Do not reuse a disconnected transport's battery percentage.
- Keep status reads separate from configuration writes. Validate report length, markers, device identity, and value ranges before accepting data. Runtime code must not depend on Keychron Engine. Keep unsupported macOS APIs behind adapters that report unavailable functionality without crashing.
- Natural Scrolling is a shared macOS setting. Unknown connection state leaves it unchanged; disabling automation and quitting leave the current setting in place. Preserve preference keys and the existing migration when changing storage.
- Keep changes focused. Preserve the current AppKit interface and use native controls. Introduce folders and boundaries as code is touched; add targets or architecture libraries only when a demonstrated need justifies them.

## Verification and delivery

For architecture refactoring, follow the reviewed [refactoring plan](docs/refactoring-plan.md). Add or strengthen behavior tests before changing the implementation. Existing-behavior tests must pass before refactoring; new contracts need a meaningful failing test before their implementation. Keep every stage green before proceeding. The user approved this plan on 2026-10-27; its execution record documents the checks.

For code changes, run the relevant native tests; run the full suite and release build when changing shared behavior, targets, dependencies, or packaging. Documentation-only changes need link and diff checks; run generation if the project manifest changes.

Tests must use fake hardware/system backends, isolated preference domains, and a private pasteboard. Retain the separate-process preferences check. Hardware coverage requires an actual device run; distinguish captured-report tests from live results. Record exact model, firmware when available, transport, report bytes, and evidence in `docs/usb-protocol.md` or the device's own notes. Never infer support for a newer mouse from another model's protocol.

Use the read-only `--read-json`, `--scroll-status`, and `--check-ui --settings` commands when live inspection is relevant. These commands must not run automation or preference migration. A disconnected mouse can make a diagnostic command exit with status 1; inspect its output before calling that a regression. Ordinary validation must not write device configuration or change the user's scrolling setting.

When changing UI, render and inspect the affected Settings pane. Describe what changed, what was checked, and any remaining limitation in plain English. Keep `PLAN.md` as a short list of requested features; mark work complete only when it exists. Preserve the MIT license, author credit, and third-party notices.
