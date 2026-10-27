# Architecture refactoring plan

**Status: approved; execution in progress.** Prepared 2026-10-27 against commit `5d4758a`. Follow the requested sequence: write the plan, review it together, then execute the agreed stages. This document does not authorize starting the rewrite before that review.

## Goal and scope

Implement [the architecture](architecture.md): thin AppKit UI, one app coordinator, shared models and policy, an M3 driver, macOS adapters, and preference storage. Keep the existing app, XCTest and persistence-probe targets. Complete the separation and folder structure, rather than stopping after file moves.

Preserve the menu and Settings behavior, USB/receiver/Bluetooth selection, JSON and diagnostic command contracts, scrolling rules, preference keys and migration, app identity, license resources, macOS 13 support, and the pinned mise/Tuist/Xcode workflow. Profiles, another real mouse, configuration writes, SwiftUI, and a Swift language-mode upgrade remain separate work.

## Test-first rule for every stage

1. Before changing existing production behavior or moving its implementation, add or strengthen tests that describe its observable contract and pass against the current implementation. Keep the existing assertions while splitting large tests into named cases.
2. For a new boundary that cannot be tested through existing code, write the proposed contract test first, introduce only the minimum seam needed to compile it, and observe a meaningful failing assertion before implementing it. Compilation failure alone is not the behavioral check.
3. Make the smallest production change, run the focused tests, then run the full suite and release build before closing the stage. Use fakes with controlled completion, time and scheduling for coordination; retain a small real run-loop test for the timer adapter.
4. Commit the green test coverage before the associated production refactor where practical. Keep each stage reviewable and independently revertible. Do not combine unrelated behavior fixes with a move; record a discovered mismatch and resolve its expected behavior explicitly.

Passing tests give evidence for the cases they exercise. Captured reports and fake transports do not establish a live hardware result. Do not use an overall coverage percentage or test count as a substitute for the contracts below.

## Starting evidence and gaps

The current suite has four XCTest methods, each containing multiple assertions:

| Existing suite | Already checks | Missing coverage needed for the rewrite |
| --- | --- | --- |
| `BatteryTests` | Captured wired/receiver decoding, malformed values, Bluetooth records, identity and priority rules | Actual reader selection with enumerated endpoints, request sequencing, retries and transport cleanup |
| `NaturalScrollingTests` | Connected/disconnected/unknown policy, write failures and retries, manual/automatic behavior, error-to-connection mapping | Coordinator integration, stopping work, and native adapter failure paths without real system writes |
| `PreferencesMigrationTests` | Valid/invalid/missing legacy settings, existing choices, repeated migration | Preserve these contracts through storage separation and startup/diagnostic routing |
| `SettingsTests` | Controls, all intervals, real timer replacement/delivery, clipboard, pane renders, separate-process persistence | Menu rendering, a shared app snapshot, startup/CLI effects, and callbacks reaching the real coordinator |

The app entry point and `AppDelegate` are excluded from the hostless test target. Several important behaviors therefore exist only inside `main.swift` today. `MouseReader` and the native system helpers also access macOS directly. Those are the first boundaries to make replaceable in tests.

Baseline commands are `mise run test` and `mise run build`. Record their fresh results below before review; do not rely only on the previous migration's checks.

## Ordered execution

### 1. Protect existing contracts

**Tests first:** expand the reachable current-code tests for unavailable versus zero battery, unknown power states, all transport priorities, disconnected versus failed reads, saved interval fallback, migration idempotence, and timer lifetime. Add fixed-input serialization tests for `MouseReading` and `NaturalScrollingState`, including optional-field omission and transport values. Keep captured and synthetic inputs labelled. Preserve the existing separate-process preferences check and Settings renders.

**Then change:** split broad test methods into named behavior cases where that helps failures explain themselves. Add shared test fixtures and fakes only as needed. No production rewrite in this stage. If testing exposes a behavior different from this plan, record it before proceeding.

**Exit:** the expanded tests pass on the original implementation; the full suite and release build pass. There is a clear list of contracts still awaiting a seam in the following stages.

### 2. Introduce shared state and extract the coordinator

**Tests first:** define coordinator tests using an injected reader, manual scheduler, held read completions, fake scrolling backend and fixed time. Exercise initial/checking/success/failure/disconnect transitions; connected with unavailable battery; no stale disconnected percentage; one in-flight read across timer, wake, menu and manual requests; interval replacement; automatic/manual changes; stopping and ignoring late completions. Check that observations reach the main thread and that inspecting/publishing state does not itself change scrolling.

**Then change:** add shared state types and small effect interfaces, initially wrapping the existing reader and scrolling implementation. Extract refresh/state/action logic from `AppDelegate` into `Sources/App/AppCoordinator.swift`. Publish one coherent snapshot, with connection certainty independent from battery availability. Keep legacy JSON output behind an explicit output model or compatibility conversion if shared types change.

Include two explicit race tests: disabling automation while a read is held must prevent a write when that read completes; a directly connected mouse discovered after a failed read must keep scrolling connection state connected, matching today's post-read presence check. Both must use controlled completions rather than sleeps.

**Exit:** the coordinator is testable without AppKit or hardware. The old menu still receives equivalent state. No HID protocol changes occur in this stage. Add and verify a behavioral failure for each new seam before implementing it.

### 3. Make UI, startup and diagnostics use the coordinator

**Tests first:** cover the menu's checking, connected, battery-unavailable, disconnected and error states, including titles, icons and actions. Test Settings callbacks against the coordinator, frozen diagnostic reports, and the real UI's consumption of a snapshot. Assert that rendering and opening panes do not trigger setting writes. Define startup/CLI tests with spies: `--read-json`, `--scroll-status`, and `--check-ui --settings` must not migrate preferences or run scrolling automation. Preserve current argument precedence, JSON fields, error output and exit-status behavior; control version/time inputs in fixtures.

**Then change:** extract menu presentation and diagnostic formatting, and give Settings shared view state instead of the concrete scrolling controller. Move startup composition and command handling into testable app code. Leave `Sources/main.swift` as the thin entry point and `AppDelegate` responsible for native lifecycle/events. Wire production readers, scheduler, preferences and system backends only at startup.

**Exit:** menu, Settings and diagnostics consume the same state; UI code has no device reads or preference writes. Read-only command tests pass with effect spies. Native pane renders are visually inspected against the baseline; live read-only inspection checks actual app wiring when relevant.

### 4. Separate the M3 driver from macOS transport access

**Tests first:** script endpoint enumeration and transport responses. Check exact VID/PID/transport/usage matching; cable → connected Bluetooth → receiver priority; unrelated interfaces ignored; connected Bluetooth without battery; stale accessory records without a connected mouse; no-target receiver replies versus timeouts; valid and malformed captures. Verify that declared capabilities include only supported status information and transports. Assert the wired open → `51 06` feature request → reads/retries → close sequence. Assert receiver callback registration before `51 0c 02`, timeout handling, and cleanup on success and every failure. Retain observed request sizes, retry limits and timing; use controlled time for timeout tests.

**Then change:** put model matching, verified capabilities, M3 command bytes, validation and decoders under `Sources/Devices/KeychronM3/`. Put HID enumeration/session access and macOS accessory enumeration under `Sources/Platform/`, behind small injected interfaces. Register the M3 driver at startup. Return shared values and typed failures; keep raw handles, callback buffers and run loops inside adapters. Convert M3 wire values into shared values at the driver boundary.

Preserve selection before reading: a selected cable's failed read reports an error; a selected Bluetooth mouse with missing battery data remains selected with an unavailable percentage. Neither case silently falls through to a lower-priority receiver. Add scripted multi-endpoint tests before changing selection. Retain three wired read attempts with 0.02-second waits after unsuccessful attempts, and the receiver's 1.2-second deadline, unless a separate behavior change is agreed.

**Exit:** no M3 IDs or report offsets appear in UI, coordinator or generic transport code. Driver tests use recorded reports and fake transports. Adapter tests use injected low-level operations to check callback/buffer lifetime and close/unregister ordering; they must not claim to prove macOS behavior on physical hardware. No second production driver or configuration-writing interface is added.

### 5. Separate scrolling policy and preference storage

**Tests first:** retain the existing policy and migration tests, then add adapter tests for missing native symbols, save failure, apply failure, and saved/live mismatch using injected native operations. Verify unknown leaves state alone, writes occur only when necessary, disabling automation leaves the current value, and stop/quit performs no restoration write. Confirm preference keys, defaults and migration marker remain identical, and that unrelated stored values are untouched. Re-run the child-process persistence check.

**Then change:** keep pure scrolling decisions under `Sources/Domain/`, native API calls under `Sources/Platform/`, and saved values/migration under `Sources/Preferences/`. Keep native library resolution and failures isolated. The coordinator invokes policy and effects; presentation only reads the resulting state.

**Exit:** shared models/policies import neither AppKit nor IOKit and perform no persistence or system calls. Tests cause no real global setting writes. Existing settings survive relaunch and migration semantics are unchanged.

### 6. Finish folders and verify the whole app

**Tests first:** all earlier behavior tests must be green before moves. Record the expected discovered test identifiers and persistence-probe execution so a broken source glob cannot silently remove coverage. Preserve a rendering test's output location when moving its file; the current renderer derives the project root from `#filePath` depth.

**Then change:** finish `Sources/App`, `Domain`, `Devices/KeychronM3`, `Platform`, `Preferences`, and `UI`; organize tests by responsibility. Update Tuist's recursive test sources to exclude `Tests/Support`, keep the app entry point excluded, and update the probe's explicit source paths. Remove superseded implementations after their replacements are covered. Update architecture docs and project rules to describe the actual layout.

**Exit:** a clean source copy, including a path with spaces, passes locked install, generation, all expected tests and release build. Verify bundle identity, minimum macOS version, resources, signature and release entitlements. Inspect Settings renders and run the read-only app diagnostics with the available mouse connection. Record which transports were live-tested; others retain fixture/fake coverage and are reported as not live-retested. Mark the reorganization item complete only after these checks.

## Completion checklist

- [ ] Tests were added before each production change, with failing new contracts and passing existing-behavior checks recorded.
- [ ] UI, coordinator, drivers, platform calls and storage have the documented ownership; the coordinator has one state writer and one active read.
- [ ] All original behavior assertions are preserved or replaced by equivalent named tests; all new tests are discovered and the persistence probe runs.
- [ ] Read-only diagnostics, settings migration, unavailable/disconnected states, transport priority and scrolling rules retain their contracts.
- [ ] Clean build/test, packaging, UI renders and available live checks have recorded results and limitations.
- [ ] README, architecture guide, AGENTS and the short feature plan match the finished code.

## Review and execution record

- Planning baseline on 2026-10-27: `mise run test` passed all four existing XCTest methods with zero failures; `mise run build` produced the signed release app successfully. Local logs: `.build/refactor-plan-baseline-tests.log` and `.build/refactor-plan-baseline-build.log`. No app source, tests, target settings, or tool versions were changed during planning. These baseline results do not close the coverage gaps listed above.
- Source review on 2026-10-27 identified additional compatibility checks: the latest automation choice must win over an in-flight read, direct presence is rechecked after failure, and endpoint read failures do not trigger transport fallback. These checks are now explicit in stages 2 and 4. This source review is not the pending user review.
- User review: approved on 2026-10-27: “Approve and execute the plan”.
- Execution: stage 1 in progress; stages 2–6 pending.

After agreement, follow the test-first loop stage by stage. Bring a material scope or behavior mismatch back for review; routine implementation choices within the agreed plan do not need another approval.
