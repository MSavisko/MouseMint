# Future development plan

Created: 2026-10-23. Status: backlog; all implementation tasks below are pending.

This plan records the requested ideas. Proposed names and architecture boundaries are starting points to refine during implementation.

## Current baseline

The app is a native AppKit menu bar utility for one Keychron M3-A3. It supports battery/status reads over USB cable, the D031 receiver, and Bluetooth; configurable status intervals; and optional automatic Natural Scrolling. Shell scripts currently build the app and run standalone Swift checks. Keychron Engine is a research reference and has no runtime role.

Preserve these working behaviors, saved preferences, and read-only diagnostics through the changes below. The [capability inventory](docs/m3-a3-capabilities.md) distinguishes verified M3 behavior from possible future controls.

## 1. Build and test with Tuist

- [ ] Choose and pin compatible Tuist and Xcode versions, documenting setup.
- [ ] Add Tuist manifests for the macOS app and test targets. Start with the existing app rather than splitting every file into a separate module.
- [ ] Preserve the bundle identifier, minimum macOS version, menu bar app behavior, resources, and local signing workflow.
- [ ] Migrate the existing decoder, scrolling-policy, settings, persistence, and timer checks into test targets. Keep hardware-dependent checks separate from tests that use fake backends.
- [ ] Document project generation, build, test, and launch commands. Decide whether the shell scripts become wrappers or are retired after parity is verified.
- [ ] Define which generated files are ignored and how a clean checkout is built.

**Done when:** a clean checkout can generate, build, and test through Tuist; the resulting app still reads the M3 and retains the user's settings after an upgrade.

## 2. Add general contributor rules in `AGENTS.md`

- [ ] Create a root `AGENTS.md` with the project purpose, source layout, supported hardware, and build/test commands.
- [ ] Describe the architecture boundaries and how to add a device or capability.
- [ ] Record the workflow preference: small, focused changes with a separate commit on `main` for each completed change, unless the user requests another workflow.
- [ ] Require accurate distinctions between confirmed disconnection, unavailable data, and an uncertain read failure.
- [ ] Keep protocol research traceable: record exact model/transport, captured reports, field validation, and sources. Keep Keychron Engine independent of the app.
- [ ] Separate status reads from configuration writes. Do not reset, flash, or change mouse settings as part of read-only discovery.
- [ ] Explain appropriate verification: pure logic tests, native UI/control checks where needed, and live hardware checks for protocol changes. Documentation-only changes need document validation rather than hardware tests.
- [ ] Preserve native macOS Settings conventions and keep utility actions in Settings.

**Done when:** a contributor can understand the rules and make a routine change using `AGENTS.md` without needing this chat history.

## 3. Document an architecture for additional devices

- [ ] Write `docs/architecture.md` describing responsibilities, dependency direction, extension points, and examples using the current M3 driver and a hypothetical second device.
- [ ] Define shared device identity, connection state, status snapshots, capabilities, and error types without embedding M3 packet offsets in shared models.
- [ ] Separate transport support from model support. USB, receiver, and Bluetooth may expose different capabilities for the same physical device.
- [ ] Define driver discovery and registration so adding a model does not require adding model-specific branches throughout the UI.
- [ ] Define how unsupported fields, stale observations, timeouts, and unavailable APIs appear to application services and the UI.
- [ ] Plan for several connected devices and transport changes. Do not assume a plugged-in receiver is a connected mouse, or merge two identical devices without identity evidence. A serial number may be unavailable; a USB port is not a stable physical-device identity.
- [ ] Define how global macOS settings are coordinated when several devices or profiles request different values.

Proposed boundaries to evaluate:

| Area | Responsibility |
| --- | --- |
| App composition | Assemble concrete services, drivers, platform adapters, and views |
| Presentation | AppKit menu, Settings panes, status display, and user actions |
| Application services | Device selection, refresh scheduling, profile activation, and scrolling policy |
| Device domain | Device descriptors, snapshots, presence states, capability contracts, and driver interfaces |
| Device drivers | Model-specific identification, validated packet decoding, and supported commands |
| Platform adapters | USB HID access, macOS Bluetooth battery access, and system scrolling APIs |
| Persistence | App preferences, versioned profiles, and migrations |

Application services should use interfaces; the composition layer supplies concrete drivers and adapters. M3-specific behavior stays in its driver. Start with clear code boundaries and introduce separate build modules where they provide a practical benefit.

**Done when:** the design explains how a second device can be added without changing existing M3 decoding or introducing device-specific logic into views. Supported capabilities and identity limitations must be explicit.

## 4. Feature: configuration profiles

- [ ] Add named profiles such as **Gaming**, **Work**, and **Default**, with create, rename, duplicate, edit, delete, and manual activation actions in Settings.
- [ ] Define a versioned profile format and migrate existing app preferences into the initial profile without losing the user's choices.
- [ ] Start with supported app settings: status-check interval and automatic Natural Scrolling behavior. Show which profile is active and retain the selection across launches.
- [ ] Allow the model to grow to device settings such as DPI stages, movement report rate, lighting, and button mappings after their read/write protocols are verified.
- [ ] Validate each setting against the selected device and transport. Explain unsupported settings instead of sending speculative commands or presenting partial application as complete success.
- [ ] For hardware writes, read back the result and report failures per setting. Define partial-failure behavior; only offer restoration where the previous value and restore operation are known to work.
- [ ] Define how a profile's global Natural Scrolling preference interacts with other devices and manual macOS changes.
- [ ] Keep profiles stored by this app distinct from firmware/onboard profiles. Do not assume the installed M3 firmware provides a particular number of onboard slots.

**Done when:** users can create and switch between Gaming and Work profiles, see the active profile, and retain it after relaunch. Supported settings apply predictably and failures or unsupported values are visible.

Possible later additions: profile import/export, per-device defaults, and optional activation based on the foreground app. These are follow-up ideas, separate from the initial manual-profile feature.

## 5. Code: refactor toward an extensible device architecture

- [ ] Move coordination out of `AppDelegate` into application services, leaving lifecycle and UI wiring in the app entry point.
- [ ] Extract a driver interface and wrap the existing M3 cable/receiver implementation behind it. Isolate macOS Bluetooth battery access behind an adapter.
- [ ] Replace fixed device selection and display assumptions with device descriptors and capability-driven presentation.
- [ ] Inject transport, preference, scheduling, and system-setting dependencies so most behavior can be tested without physical hardware or changing macOS settings.
- [ ] Keep one serialized request path per device/session; handle cancellation, disconnects, wake, transport changes, and cleanup explicitly.
- [ ] Keep app preferences and profile storage independent of wire formats and UI controls.
- [ ] Migrate incrementally, retaining the existing protocol fixtures and behavior checks throughout the refactor.
- [ ] Prove the extension points with a fake second-device driver. Validate a real second model separately before claiming hardware support.

**Done when:** the M3 retains its verified behavior and a second driver can be registered without modifying M3 packet parsing, scrolling policy, or generic Settings controls. Tests cover unsupported capabilities, device selection, and uncertain connection states.

## Suggested implementation sequence

1. Establish the Tuist build and test baseline.
2. Add `AGENTS.md` using the verified commands and conventions.
3. Agree on and document device-extension boundaries.
4. Refactor in small steps toward those boundaries.
5. Add manual profiles on top of the resulting services and persistence model.

Hardware configuration controls and automatic profile activation can then be added as separate features, each backed by protocol evidence and appropriate verification.
