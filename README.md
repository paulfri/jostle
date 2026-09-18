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

Jostle is a native menu bar utility for controlling windows without hunting for title bars or tiny resize handles, and for preventing idle sleep when you need your Mac to stay awake. Hold a modifier, point anywhere inside a window, and drag, or start a timed Keep Awake session from the same menu bar icon. Jostle stays out of the Dock and offers snapping, per-app exclusions, configurable spacing, automation, and optional launch-at-login and update checks.

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

## Keep Awake

Choose **Keep Awake** in Jostle's menu to prevent idle sleep indefinitely or for 10 or 30 minutes, or 1, 2, 4, 8, or 12 hours. By default, left-clicking the menu bar icon opens the menu and right-clicking toggles Keep Awake using your preferred duration. You can swap those actions or assign a global keyboard shortcut in Settings.

Jostle's four-corner frame stays fixed in the menu bar: its center is empty at rest, shows a cup during Keep Awake, and shows a moon when a session is paused while the screen is locked. This state remains visible even when window gestures are unavailable.

The Keep Awake settings also let you:

- Allow the display to sleep while keeping the Mac itself awake
- Pause the assertion and countdown while the screen is locked
- Turn Keep Awake off when the Mac switches from external power to battery
- Start a session when Jostle launches
- Choose the branded cup, a green or blue cup, or a fully colored active icon, and optionally dim the icon while inactive
- Use a monotonic timer that remains accurate across sleep and clock changes
- Show a notification when a timed session finishes

Keep Awake is independent of Jostle's Accessibility permission, so it remains available even if window controls are disabled.

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
  <img src="docs/screenshots/settings-general.png" width="720" alt="Jostle Gestures settings with the Calm frame identity">
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
- Ignore selected applications, including apps without bundle identifiers
- Temporarily disable window controls from the menu bar icon
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

Jostle uses the macOS Accessibility API to find the window under the pointer and update its position and size. It does not require Screen Recording permission. Apps that do not expose movable or resizable windows through Accessibility may not respond to every action.

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

The repository is split into a small AppKit/SwiftUI menu bar app in `Jostle/` and a deterministic Swift package in `JostleCore/` for event policy, gesture state, geometry, snapping, Keep Awake commands, URL parsing, and settings behavior.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidance and [docs/releasing.md](docs/releasing.md) for the signed release process.

## Heritage and license

Jostle continues the idea behind Daniel Marcotte's Easy Move+Resize with a native Swift implementation maintained by Paul Friedman.

Released under the [MIT License](LICENSE.txt).
