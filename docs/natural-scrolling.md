# Automatic Natural Scrolling

Added 2026-10-23 for the user's requested rule: **off when the M3 is connected, on when it is disconnected**. This intentionally changes macOS's shared mouse/trackpad setting. It runs only while MouseMint is open.

## Settings controls

The menu's **Settings…** row opens a native window with a noncustomizable preferences toolbar. It switches between **General**, **Natural Scrolling**, **Diagnostics**, and **About**; the selected pane is highlighted. General contains a saved status-interval slider (2, 3, 5, 8, 10 seconds; default 5). Natural Scrolling contains short explanations and two switches:

- **Automatically switch Natural Scrolling** enables the connection rule below. Its value is stored in the app's `automaticallySwitchNaturalScrolling` preference, defaulting to true when absent to preserve existing behavior. Turning it off does not write the system scrolling setting. Connection checks and battery monitoring continue, but no connection observation can apply a scrolling change while disabled, including an in-flight query. Re-enabling requests a fresh connection reading.
- **Natural Scrolling** reflects the live native value. It is editable only while automation is off and the native setting is available. Manual changes use the same verified backend as automatic changes. Disabling automation also lets changes made in macOS Settings persist.

The menu shows `(automatic)` or `(manual)` beside the live setting. The Settings window updates with each refresh and displays application errors. Closing the window does not change either setting.

**Diagnostics** contains the current read-only report, **Refresh Now**, and **Copy Diagnostics**. The copied content matches the current preview, and a confirmation appears after copying. Refresh uses the app's existing asynchronous reader and disables the button while it runs. Reports include the app/macOS versions, battery, connection, raw report or Bluetooth battery source, scrolling preference/live values, and errors. **About** shows the version and app description. Refresh, copying, About, and detailed error messages have moved out of the status menu; Settings and Quit remain there as standard app actions.

## Applying the setting

The implementation saves `com.apple.swipescrolldirection` in the current user's global, any-host preferences using `CFPreferencesSetValue` and `CFPreferencesSynchronize`.

Saving the preference alone does not reliably apply the active scroll direction. `SystemNaturalScrolling` dynamically loads:

```text
/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport
swipeScrollDirection:    () -> Bool
setSwipeScrollDirection: (Bool) -> Void
```

Both symbols were present on this Mac and in its Xcode macOS SDK's `PreferencePanesSupport.tbd`. The setter applies the native setting immediately. After every change, the app verifies both the saved preference and the native getter. Missing functions and failed writes/applications are reported in the menu and diagnostics. No fallback claims success merely because a preference changed. No Accessibility permission, event tap, input interception, settings-window automation, or helper installation is involved.

The native setter/getter route is unsupported macOS API. It is loaded at runtime to avoid a hard launch dependency if Apple removes it. The implementation was independently written in Swift; research references are [Natural's source](https://github.com/davidalecrim1/natural/blob/76caac00a390e4cb105e9e1076038e3bb52b15d5/src-tauri/src/scroll.rs) and the [Swift implementation author's explanation](https://blog.onethinglab.com/macos-change-scrolling-mode-from-swift/).

## Connection policy

| Observation | Scrolling action |
| --- | --- |
| Successful M3 reading over cable, receiver, or Bluetooth | Natural Scrolling off |
| Cable/Bluetooth M3 still enumerated, even if battery read fails | Off |
| No matching connected device | On |
| D031 receiver's complete `54 e4 02 00 ... 00` no-target reply | On |
| Receiver timeout, malformed battery report, USB access/request/read failure without direct-mouse evidence | Leave the current setting unchanged |

A plugged-in receiver does not establish that a mouse is connected. The receiver handler distinguishes a confirmed no-target reply from an uncertain timeout; only the former establishes disconnection. Incomplete, unrelated, or other receiver acknowledgements do not count as no-target replies.

When automation is enabled, the app uses the status interval chosen in General and also checks on wake/menu opening. It reads the preference and native setting before applying its rule, avoiding repeated writes while they already match. A manual setting change is corrected on the next confirmed observation. Quitting leaves the current setting in place and stops automatic switching.

## Diagnostics

```sh
"dist/MouseMint.app/Contents/MacOS/MouseMint" --scroll-status
```

Example when the mouse is disconnected:

```json
{
  "live": true,
  "preference": true
}
```

`--scroll-status`, `--read-json`, and `--check-ui` are read-only; they do not change Natural Scrolling. The running app performs the automatic changes.

## Verification

- The native backend applied On, reported `preference: true` and `live: true`, then applied Off and reported both false. The initial Off value was restored after this round-trip check.
- The normal app launched with a cable-connected M3 and displayed `Natural Scrolling: Off (automatic)`.
- After the user disconnected the mouse, HID enumeration showed no M3/receiver. The running app automatically changed the saved preference to `1`; the native getter reported true. Its menu showed `Not connected` and `Natural Scrolling: On (automatic)`. The user confirmed trackpad scrolling felt correct.
- After reconnecting the USB-C receiver and switching the mouse to 2.4 GHz with its cable unplugged, the running app automatically changed both saved and native values to false. The menu showed the receiver connection, 100% battery, and `Natural Scrolling: Off (automatic)`. The user confirmed mouse-wheel scrolling felt correct.
- Automated checks cover connected/disconnected/unknown transitions, unchanged-state writes, reconnects, mismatched saved/live values, failure visibility and retry, direct-mouse evidence during battery errors, and receiver no-target acknowledgement validation. They use an injected backend and do not change system settings.
- Settings checks exercise the real native switches' target/actions with an injected scrolling backend: disabling performs no system write, connection changes cannot override manual mode, manual changes apply, and re-enabling resumes the connection rule. A separate process verifies the disabled preference survives a relaunch using an isolated test domain. The native Settings content was rendered and visually inspected for readable explanations and unclipped controls.
- The final app's `--check-ui --settings` check confirmed a live receiver reading at 100%, the Settings menu row and window, the saved automatic switch On, and the manual switch reflecting Off and disabled while automation is active.
- The pane update was verified with all three native toolbar target/actions, selected-item highlighting, asynchronous-refresh button states, and exact copied text in a private pasteboard. Full native window renders were inspected for each pane and copy confirmation. A final `--check-ui --settings` run on version 1.4 (5) confirmed the status menu contains Settings and Quit as its only actions, all three pane labels are present, and Diagnostics contains the live cable-connected M3's 100%/fully charged report, versions, and scrolling values.
- Version 1.5 adds General and the interval slider. Native control tests exercised all five values, invalid-value fallback, replacement of the previous timer, actual two-second run-loop delivery, absence of further callbacks from the replaced timer, and persistence in a separate process. The full General window was rendered and visually inspected. Read-only final-app checks with temporary command-line preference overrides confirmed real timer intervals of 2, 3, 5, 8, and 10 seconds, each with a successful live wired battery reading. These overrides did not change the user's saved interval or system scrolling.
- Version 1.6 renames the app to MouseMint and uses the preference domain `io.github.msavisko.mousemint`. Its first normal launch imports the automatic-scrolling choice and valid status interval from `local.keychroncharge`, without replacing existing MouseMint choices. Diagnostic commands do not run the migration. Tests cover missing and invalid old settings, partial imports, existing choices, and repeated launches. The live upgrade preserved automatic switching enabled and a two-second interval; the renamed menu and Settings window correctly showed the disconnected mouse state. The About pane was rendered and visually checked.
