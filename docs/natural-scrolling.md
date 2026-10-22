# Automatic Natural Scrolling

Added 2026-10-23 for the user's requested rule: **off when the M3 is connected, on when it is disconnected**. This intentionally changes macOS's shared mouse/trackpad setting. It runs only while Keychron Charge is open.

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

The app checks every five seconds and on wake/menu opening. It reads the preference and native setting before applying its rule, avoiding repeated writes while they already match. A manual setting change is corrected on the next confirmed observation. Quitting leaves the current setting in place and stops automatic switching.

## Diagnostics

```sh
"dist/Keychron Charge.app/Contents/MacOS/KeychronCharge" --scroll-status
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
