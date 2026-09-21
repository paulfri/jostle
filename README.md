<p align="center">
  <img src="Jostle/Images.xcassets/AppIcon.appiconset/icon_256x256@2.png" width="128" height="128" alt="Jostle logo">
</p>

<h1 align="center">Jostle</h1>

<p align="center"><strong>Move, resize, and tile macOS windows—and keep your Mac awake—from one menu bar app.</strong></p>

<p align="center">
  <a href="https://github.com/paulfri/jostle/releases/latest"><img src="https://img.shields.io/github/v/release/paulfri/jostle?display_name=tag&sort=semver" alt="Latest release"></a>
  <a href="https://github.com/paulfri/jostle/actions/workflows/ci.yml"><img src="https://github.com/paulfri/jostle/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple" alt="macOS 13 or later">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
</p>

Jostle is a native menu bar utility for controlling windows without hunting for title bars or tiny resize handles, customizing mice and trackpads, and preventing idle sleep when you need your Mac to stay awake. Hold a modifier or an extra mouse button and drag from anywhere inside a window, tune scrolling by device and app, let focus follow the pointer, or start a timed Keep Awake session from the same menu bar icon. Jostle appears in the Dock only while Settings is open and offers snapping, contextual input profiles, configurable spacing, automation, and optional launch-at-login and update checks.

## Controls

The default modifier is **Control** (`⌃`). Jostle only responds when the exact configured modifier combination is held.

| Action | Default gesture |
| --- | --- |
| Move a window | `Control` + left-drag |
| Resize a window | `Control` + right-drag near the edge or corner you want to move |
| Maximize or restore | `Control` + double-left-click |
| Tile by clicked region | `Control` + double-click with the resize button |
| Snap while moving | Drag to a screen edge or corner, then release |
| Cancel an active move or resize | `Escape` |

The resize button can be changed from right click to middle click. Modifier keys, double-click actions, snapping, resize feedback, tile gaps, and screen margins are all configurable from Settings.

The **Apps** settings let you choose the defaults for window controls and Focus Follows Pointer, then override either behavior for individual applications. This supports include-only setups such as enabling pointer focus for every `eqgame.exe` window while leaving all other applications unchanged. Focus can be immediate or delayed until the pointer rests.

## Mouse and trackpad customization

Enable **Input Customizations** from Jostle's menu or its **Input** settings tab. Jostle provides:

- Independent reverse-scrolling defaults for mice and trackpads
- Ordered scroll profiles matched by device type, exact device, application bundle ID, or process name
- Independent vertical and horizontal distance, speed, acceleration, smoothing curve, response, inertia, and bounce controls
- Button 4 and Button 5 mappings for Back, Forward, move, resize, maximize, left/right tile, next display, and Keep Awake
- A universal Back/Forward preset that maps otherwise-unassigned side buttons to `⌘[` and `⌘]`
- Per-device scrolling and Focus Follows Pointer overrides for connected or previously configured pointing devices
- An optional battery percentage beside the menu bar icon, with device details in the menu, for pointing devices that expose the standard Bluetooth Battery Service

On first launch with an existing `~/.config/linearmouse/linearmouse.json`, Jostle imports the supported scrolling and universal Back/Forward settings once when the referenced pointing device is available. Disabled auto-scroll, disabled gesture actions, Logitech high-resolution-wheel controls, and vendor-specific settings are intentionally not imported.

Button-held move and resize use the same safe window engine as Jostle's modifier gestures. A gesture remains bound to its initiating button through drag and release, and `Escape` cancels it. Input processing is fail-open: unsupported devices and unhandled events keep native macOS behavior.

Input customization requires Accessibility permission. Bluetooth battery display requests Bluetooth access only when enabled. Input can be disabled independently of window gestures and Keep Awake. After repeated unclean launches, Jostle starts in Safe Mode with input interception disabled. See [Input customization support and privacy](docs/input-customization.md) for supported-device boundaries, diagnostics, compatibility warnings, backups, and troubleshooting.

### Input recovery

Hold **Shift-Option** while opening Jostle to enter Safe Mode for one launch. From Terminal, quit the running release app and reopen Settings without input interception:

```sh
osascript -e 'tell application id "fm.pau.jostle" to quit' 2>/dev/null || pkill -x Jostle
open -na "/Applications/Jostle.app" --args --safe-mode --show-settings
```

Replace the app path if Jostle is installed elsewhere. To persistently turn input customization off while preserving its profiles, replace `--safe-mode` with `--disable-input-customizations`. To erase only input customization settings, use `--reset-input-customizations`; window, Keep Awake, login, update, and per-application settings remain unchanged.

For the signed development app used by this repository:

```sh
osascript -e 'tell application id "fm.pau.jostle.development" to quit' 2>/dev/null || pkill -x "Jostle Development"
open -na "$HOME/Applications/Jostle Development.app" --args --safe-mode --show-settings
```

## Keep Awake

Choose **Keep Awake** in Jostle's menu to prevent idle sleep indefinitely or for 10 or 30 minutes, or 1, 2, 4, 8, or 12 hours. By default, left-clicking the menu bar icon opens the menu and right-clicking toggles Keep Awake using your preferred duration. You can swap those actions or assign a global keyboard shortcut in Settings.

Jostle's vector-drawn four-corner frame stays fixed in the menu bar: its center is empty at rest, shows a bolt during Keep Awake, and shows a moon when a session is paused while the screen is locked. An available pointing-device battery percentage can appear beside it. This state remains visible even when window gestures are unavailable.

The Keep Awake settings also let you:

- Allow the display to sleep while keeping the Mac itself awake
- Pause the assertion and countdown while the screen is locked
- Turn Keep Awake off when the Mac switches from external power to battery
- Start a session when Jostle launches
- Choose a monochrome, green, blue, or fully colored bolt treatment, and optionally dim the icon while inactive
- Show a notification when a timed session finishes

Timed sessions always use monotonic timing so they remain accurate across sleep and system-clock changes. Keep Awake is independent of Jostle's Accessibility permission, so it remains available even if window controls are disabled.

### Automation

Jostle includes native Shortcuts actions named **Set Keep Awake State** and **Get Keep Awake State**. Set can turn Keep Awake on or off, toggle it, use the configured default duration, run indefinitely, or accept a custom duration in seconds.

You can also open `jostle:` URLs:

```sh
open 'jostle:activate'
open 'jostle:activate?hours=1&minutes=30'
open 'jostle:deactivate'
open 'jostle:toggle?minutes=10'
```

Duration parameters may use `hours` and `minutes` together. Values must be greater than zero and within the supported range.

## Screenshots

<p align="center">
  <img src="docs/screenshots/settings-general.png" width="720" alt="Jostle General settings">
</p>
<p align="center"><sub>Configure Jostle from a native, frame-branded Settings window.</sub></p>

## Features

- Move and resize from any point inside a window
- Snap to screen halves, quarters, or the full usable display, with a live preview
- Restore a snapped or maximized window to its previous frame
- Choose any combination of Control, Option, Shift, Command, and Function
- Use right click or middle click for resizing
- Show the active resize edge while dragging
- Add gaps between tiled windows and margins around the screen
- Reverse scrolling independently for mice, trackpads, and individual pointing devices
- Tune per-axis scroll distance, speed, acceleration, smoothing, inertia, and bounce by device, app, or process
- Show standard Bluetooth pointing-device battery levels beside the menu bar icon and in its menu
- Map extra mouse buttons to window, navigation, display, and Keep Awake actions
- Move and resize windows by holding an extra mouse button
- Configure window controls and Focus Follows Pointer independently per app and pointing device
- Match apps without bundle identifiers, including Wine-hosted executables such as `eqgame.exe`
- Choose immediate pointer focus or a 100, 250, or 500 ms dwell delay
- Temporarily disable all window features from the menu bar icon
- Keep the Mac awake indefinitely or for a selected duration
- Control Keep Awake by menu-bar click, global shortcut, `jostle:` URL, or Shortcuts action
- Pause while locked or deactivate automatically when switching to battery power
- Start automatically at login
- Install signed updates with Sparkle; automatic checks are opt-in

## Install

Jostle requires **macOS 13 Ventura or later**.

1. Download the DMG from the [latest release](https://github.com/paulfri/jostle/releases/latest).
2. Open it and drag **Jostle** into **Applications**.
3. Launch Jostle and grant the requested **Accessibility** permission.
4. Use the Jostle icon in the menu bar to open Settings or enable launch at login.

Reopen Jostle after granting Accessibility access if macOS does not activate it immediately. Jostle is distributed outside the Mac App Store and release builds are Developer ID signed and notarized by Apple.

## Accessibility permission

Jostle uses the macOS Accessibility API to find the window under the pointer, update its position and size, and raise it when Focus Follows Pointer applies. It does not require Screen Recording permission. Apps that do not expose movable or resizable windows through Accessibility may not respond to every action.

If Jostle loses permission or its event monitor stops, the menu bar icon dims and its menu provides an action to fix or retry the unavailable service.

## Build from source

You will need macOS and Xcode.

```sh
git clone https://github.com/paulfri/jostle.git
cd jostle
open Jostle.xcodeproj
```

Select the **Jostle Development** scheme and run it. Development builds use a separate bundle identifier, settings store, app icon, and Accessibility entry so they can coexist with an installed release.

Run the complete test suite from the command line:

```sh
xcodebuild \
  -project Jostle.xcodeproj \
  -scheme 'Jostle Development' \
  -destination 'platform=macOS' \
  -derivedDataPath build-tests \
  CODE_SIGNING_ALLOWED=NO \
  test

swift test --package-path JostleCore
```

The repository is split into a small AppKit/SwiftUI menu bar app in `Jostle/` and a deterministic Swift package in `JostleCore/` for event policy, input profiles, gesture state, geometry, snapping, Keep Awake commands, URL parsing, and settings behavior.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidance, [docs/releasing.md](docs/releasing.md) for the signed release process, and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for third-party code provenance and licenses.

## Heritage and license

Jostle continues the idea behind Daniel Marcotte's Easy Move+Resize with a native Swift implementation maintained by Paul Friedman.

Released under the [MIT License](LICENSE.txt).
