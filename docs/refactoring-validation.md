# Refactoring validation

The six-stage architecture plan was approved on 2026-10-27 and executed with tests before implementation. This record separates automated coverage from live hardware checks. The app keeps its original macOS 13 minimum, Swift 5 mode, identity, preferences and three Tuist targets.

## Test-first evidence

The planning baseline passed four broad XCTest methods. Their assertions remain in the expanded suite. Existing-behavior checks passed before extraction; new boundaries were introduced as compiling stubs, observed failing behavior tests, then implemented. Compilation errors encountered while wiring targets are not counted as behavioral failures.

| Stage | Added protection | Passing methods at stage end | Local evidence |
| --- | --- | --- | --- |
| 1 | Serialization, unavailable/zero values, transport priority, errors, migration and timer contracts | 15 | `.build/stage1-tests.log`; commit `bbcabe4` |
| 2 | One active read, state transitions, stop/restart, late results, automation races, scheduling and main-thread delivery | 27 | `.build/stage2-red.log`, `stage2-adapter-red.log`, `stage2-final-tests.log`; commit `80b3c27` |
| 3 | Real menu/Settings actions, shared snapshots, diagnostic formatting and read-only startup routing | 34 | `.build/stage3-red.log`, `stage3-final-tests.log`; commit `77d6a8d` |
| 4 | Driver selection, exact requests/retries, receiver deadlines, typed failures and native session lifetime | 48 | `.build/stage4-red.log`, `stage4-session-red.log`, `stage4-accessory-red.log`, `stage4-metadata-red.log`, `stage4-complete-tests.log`; commit `a7035cc` |
| 5 | Native scrolling failures, save/apply verification, isolated storage and unchanged migration | 53 | `.build/stage5-behavior-red.log`, `stage5-complete-tests.log`; commit `4bb0de4` |
| 6 | Discovered test inventory, folder-independent renders and independently tested pure scrolling decisions | 56 | `.build/stage6-before-moves.log`, `stage6-after-moves.log`, `stage6-policy-red.log`, `stage6-policy-green.log` |

The pure scrolling-policy check in stage 6 completed the separation of decisions from effects: `Domain/ScrollingPolicy` returns a desired value, while `App/AutomaticNaturalScrolling` applies it through injected interfaces. Its initial stub produced two assertion failures before implementation.

Each completed extraction stage passed the full native suite and a release build. Stage 6 retained all 53 pre-move test identifiers and added three pure policy methods. The separate-process preferences probe remains part of `SettingsTests`; it runs against an isolated preferences domain. Settings tests use a private pasteboard. Hardware and system operations use fakes, so the suite does not change the user's global scrolling setting or device configuration.

## Final checks

Completed on 2026-10-27. Logs and rendered images are local ignored build artifacts, not repository resources.

- Standalone compilation of `Sources/Domain/*.swift` passed with the macOS 13 target. It requires no AppKit, IOKit, UI, preference storage or platform implementation.
- The source layout and ownership are documented in [architecture.md](architecture.md). The original four test methods, legacy JSON keys, preference keys and migration marker are preserved.
- A fresh source copy at `/private/tmp/MouseMint refactor 2kv8fyup`, without generated projects, build outputs or project caches, passed `mise install --locked`, `mise run generate`, `mise run test` and `mise run build`. The path includes spaces. Xcode's result bundle confirms all 56 expected methods passed, with the same identifiers as the working-copy run. Local log: `.build/refactor-clean-validation.log`.
- Both release bundles passed strict code-signature verification. Bundle ID remains `io.github.msavisko.mousemint`, version `1.6.1` (8), minimum macOS `13.0`, with `LSUIElement` enabled. MIT `LICENSE` and `THIRD_PARTY_NOTICES.md` match the repository byte for byte; no stale `LICENSE.txt` or debugging `get-task-allow` entitlement is present. No tools or Swift packages were added.
- Tests produced General, Natural Scrolling, Diagnostics and About renders in each copy's `.build` directory. All four working-copy panes were visually inspected: native controls, labels and actions remain readable without clipping. The About render uses the hostless test bundle's version; the actual app's command inspection reports `1.6.1` (8).
- Final `--read-json`, `--scroll-status` and `--check-ui --settings` all exited 0. The connected cable mouse reported 100%, fully charged; the real menu and Settings diagnostic report agreed. Saved app choices, migration marker and global scrolling preference matched before and after these commands. Saved and live scrolling were both Off. Local output: `.build/stage6-live-checks.json`.
- Ordinary validation did not run the app's automation or write mouse configuration. The final app is available at `dist/MouseMint.app`; reopen it to use the refactored executable in the normal menu bar session.

## Hardware limits

Driver tests exercise captured M3-A3 reports and synthetic malformed reports through scripted transports. Native adapter tests verify injected operation order and lifetime; they do not prove physical macOS/HID behavior. Earlier live evidence for cable, Bluetooth and the D031 receiver remains in [usb-protocol.md](usb-protocol.md). No support for another mouse, receiver variant or configuration writes is implied by this refactor.

The final refactored executable was live-tested over the currently connected USB cable only. Bluetooth, receiver operation and physical connection transitions were not live-retested during this execution. The new cable capture and firmware limitation are recorded in [the protocol notes](usb-protocol.md#refactoring-live-check--2026-10-27).
