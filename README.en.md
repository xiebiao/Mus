<p align="center">
  <img src="Resources/IconVariants/Mus-Mouse-Template.png" width="128" alt="Mus mouse silhouette logo">
</p>

# Mus

[简体中文](README.md) | **English**

**Small app. Better control.**

**Mus is a lightweight, simplified alternative to Logi Options+. It currently supports only the MX Anywhere 3S.**

A native macOS menu bar utility for side-button shortcuts, scroll direction, and wheel tuning.

Swift / SwiftUI · macOS 14+ · Simplified Chinese / English · MIT

[Quick start](#quick-start) · [Usage](#usage) · [FAQ](#faq) · [Contributing](#contributing)

## Why Mus?

If all you need is side-button mapping and scroll tuning, Mus provides a simple settings window that lives in your menu bar. No account, cloud service, additional driver, or third-party runtime dependency is required. Your settings stay on your Mac.

Mus was built for everyday use with the MX Anywhere 3S and works through standard macOS mouse events. The MX Anywhere 3S is currently the only supported model; other models are outside the supported scope.

## Features

- **Side-button shortcuts**: Back/Forward, Copy/Paste, Undo/Redo, New/Close Tab, Mission Control, Show Desktop, and switching desktops. You can also record a custom shortcut, keep the original behavior, or disable a button.
- **Button identification**: Learn the actual button number by pressing a side button, with visual position hints to help resolve reversed front/rear mappings.
- **Scroll tuning**: Adjust speed, minimum step, and smoothing duration. Reverse vertical and horizontal scrolling independently.
- **Device information**: Display the brand, model, and connection reported by the system, including Bluetooth and Logi Bolt receiver detection.
- **Menu bar access**: Pause or resume at any time, keep running after closing the window, and optionally launch at login.
- **Two interface languages**: Follow the system language or choose Simplified Chinese or English. Changes take effect immediately.
- **Local operation**: No network requests, telemetry, input history, or global keyboard monitoring.

> Version 0.1.0 is an early release. Settings affect matching side buttons and standard wheels on all mice; per-device and per-app profiles are not yet supported. Bluetooth device detection has been verified with an MX Anywhere 3S. Its complete input behavior over Logi Bolt still needs hardware testing.

## Quick start

### Build from source

Requires macOS 14 or later and Swift 5.9+ through Xcode or Command Line Tools.

```sh
git clone https://github.com/xiebiao/Mus.git
cd Mus
bash scripts/build-app.sh
open build/Mus.app
```

The build script generates the icons, compiles the app, and signs `build/Mus.app`. It builds for your Mac's architecture by default and does not download external Swift packages. For regular use, move the app to Applications before granting permissions.

Local builds use an ad-hoc signature and are not notarized by Apple.

### Grant Accessibility access

1. Open Mus and click **Open permission settings**.
2. Enable Mus in **System Settings → Privacy & Security → Accessibility**. If it is missing, use `+` to add the current app.
3. Return to Mus, click **Check again**, and confirm **Event monitoring: Running**.
4. Disable overlapping button mappings or scroll processing in other tools before testing Mus.

Closing the window leaves Mus running in the menu bar. Click the mouse icon to open Preferences, pause, or quit. Launch at login is available under **Setup & permissions**.

## Usage

### Side buttons

By default, the front button sends Forward (`⌘]`) and the rear button sends Back (`⌘[`). If the order is wrong, click **Identify** on the corresponding row and press that button. The identifying click does not trigger a mapped action, and identification cancels after 12 seconds without input.

Choose an action from the dropdown, or select the custom shortcut option to record a combination. Recording only receives keystrokes while the in-app recorder has focus. Press Escape to cancel.

| System action | Default shortcut |
| --- | --- |
| Mission Control | `Control + ↑` |
| Show Desktop | `F11` |
| Switch to the left/right desktop | `Control + ← / →` |

These actions depend on your macOS keyboard shortcut settings. If you have changed them, record your own combination. Switching desktops requires another Space in the chosen direction.

### Scrolling

**Customize scrolling** is off by default. When enabled, it provides:

| Setting | Range | Default | Effect |
| --- | --- | --- | --- |
| Scroll speed | 0.25–3× | 1× | Scales the distance of each scroll input |
| Minimum step | 1–80 pixels | 12 pixels | Sets a minimum distance for nonzero input, before applying the speed multiplier |
| Smooth scrolling | On/off | On | Distributes movement across multiple frames |
| Smoothing duration | 80–600 ms | 200 ms | Shorter feels more immediate; longer feels softer |

For finer scrolling, **lower the speed first**. Minimum step is a lower bound: reducing it alone may have little effect when the system already reports larger scroll deltas. Try 0.5× speed and a 300 ms smoothing duration as a starting point.

Vertical and horizontal reversal are independent and are relative to your current macOS direction. Continuous scrolling from trackpads and Magic Mouse is left unchanged.

### Brand and connection detection

| Detected connection | Meaning |
| --- | --- |
| Bluetooth | Identified from the device's reported Bluetooth / Bluetooth Low Energy transport |
| Logi Bolt wireless receiver | Identified by Logitech USB ID `046d:c548` |
| USB wireless receiver | The device name explicitly identifies it as a receiver |
| USB (wired or receiver) | The system only reports USB; a wired mouse cannot reliably be distinguished from another wireless receiver |

Device discovery does not require Accessibility access. **Connected and Event monitoring: Running are separate states.** Detecting a receiver does not mean its paired mouse is online. Mus does not currently query HID++ paired devices or infer their models.

## Compatibility and limitations

- Settings apply to all matching standard mouse events, rather than one specific mouse.
- Left, right, and middle clicks are not remapped. A side button triggers once per press; holding or repeating a shortcut is not simulated.
- DPI, battery level, SmartShift, per-app profiles, and writing settings to onboard memory are not supported yet.
- Scroll tuning changes software movement, not hardware resolution. Continuous and momentum events are skipped. Custom scroll tuning also preserves native Control/Command + wheel operations.
- Other mouse tools may transform events before Mus receives them, preventing button identification or scroll tuning.
- Moving the pointer, clicking, switching the foreground app, or changing settings cancels pending smoothing so delayed scrolling does not affect a new target.

## FAQ

### Why does Mus still request Accessibility access after I enabled it?

Make sure the permission belongs to the running copy of Mus, not an old path or version. Moving or rebuilding the app may invalidate its existing permission because of local signing. Quit Mus, remove the old entry from Accessibility settings, add the current app, and then relaunch and check again.

### Why do shortcuts not work even though my mouse is detected?

Check that the main toggle is enabled and event monitoring is running, then use **Identify** to confirm the button number. Test the target shortcut with your physical keyboard first, and disable overlapping mappings in other tools. Actions such as Back/Forward depend on the foreground app.

### Why does scroll tuning seem to have little effect?

Make sure **Customize scrolling** is enabled and Accessibility access is granted, then try a lower speed. Some devices or other smoothing tools may report wheel input as continuous events, which Mus skips. Reducing minimum step does not necessarily reduce larger existing scroll deltas.

### Will my settings survive an upgrade from Tiny Mouse?

Mus attempts to migrate valid mouse settings and language preferences from older versions without overwriting settings already saved by Mus. The new bundle identifier is `local.mus.app`, so check permissions again. Disable any old login item to avoid running both versions at once.

### How do I uninstall Mus?

Disable launch at login, quit Mus, and delete the `.app`. You can remove its Accessibility entry in System Settings. Deleting the app does not automatically erase local preferences.

## Development

```sh
swift test
bash scripts/build-app.sh

# Read-only diagnostics
build/Mus.app/Contents/MacOS/Mus --self-check
build/Mus.app/Contents/MacOS/Mus --list-mice

# Package as ZIP
ditto -c -k --sequesterRsrc --keepParent build/Mus.app build/Mus.zip
```

`--self-check` inspects the current process. Terminal and GUI permissions may differ, so rely on the app's status. `--list-mice` prints the brand, model, and connection without serial numbers or Bluetooth addresses.

- `Sources/MouseCore/`: Settings, input transformations, shortcut events, and scroll calculations.
- `Sources/Mus/`: UI, event monitoring, device discovery, permissions, and login items.
- `Tests/`: Event processing, scrolling, device classification, settings migration, and localization tests.
- `scripts/`: Icon generation and app packaging.

See the [development documentation](docs/DEVELOPMENT.md) and [validation notes](docs/VALIDATION.md) for implementation details and manual testing steps (currently in Chinese). Set `SIGN_IDENTITY` to use an existing local signing identity. The build scripts do not perform Apple notarization.

## Contributing

[Issues](https://github.com/xiebiao/Mus/issues) and pull requests are welcome, especially compatibility reports for the MX Anywhere 3S over Bluetooth or Logi Bolt.

Include your macOS version, mouse model, connection type, reproduction steps, and expected behavior. **Setup & permissions → Copy diagnostics** can help describe the issue. Do not include device serial numbers or other personal information.

Before submitting code, run `swift test` and `bash scripts/build-app.sh`. Update both Simplified Chinese and English resources when adding UI text. Include appropriate validation for behavior changes, and avoid sending test input to the real desktop.

## License and acknowledgments

Mus source code is licensed under the [MIT License](LICENSE). Images, generated icons, and third-party assets have separate terms described in [asset attribution](Resources/ATTRIBUTION.md) (Chinese); they are not automatically covered by the code license. Original permissions for some reference photos and derived assets have not yet been fully confirmed. Verify or replace those assets before distributing your own build.

- [Mos](https://github.com/Caldis/Mos): Product inspiration for scroll tuning. Mus implements its own smoothing logic.
- [Solaar](https://github.com/pwr-Solaar/Solaar): Reference for device identifiers. Its implementation was not copied.
- [Lucide](https://lucide.dev): An earlier icon option; its license notices remain in the asset directory.

Mus is an independent project and is not affiliated with or endorsed by Logitech.
