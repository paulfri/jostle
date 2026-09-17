# Jostle

Move and resize macOS windows by modifier-dragging anywhere inside them.

Jostle is a small native Swift menu-bar utility inspired by X11/Linux window managers and [Easy Move+Resize](https://github.com/dmarcotte/easy-move-resize).

> **Current status:** source-only preview. Binary releases are not published yet.

## Usage

The default modifier combination is **Command + Control**:

- **Left-drag** anywhere inside a window to move it.
- **Right-drag** anywhere inside a window to resize it.
- The resize direction is chosen from the region where the drag starts.
- While moving, drag to the left or right screen edge for a half, a corner for a quarter, or the top edge to fill the usable screen. Jostle previews the target before the mouse is released.
- Dragging a window after Jostle snaps it restores its previous size while keeping the pointer at the same relative position.
- Modifier-double-left-click maximizes or restores a window. Modifier-double-click with the configured resize button tiles toward the clicked edge or corner.
- Press **Escape** during a move or resize gesture to cancel it and restore the exact frame from before the gesture began.
- Resizing enforces a conservative 160×100-point fallback minimum and synchronizes with larger size constraints imposed by the target application.

The compact menu-bar menu lets you enable or disable Jostle, toggle exclusion for the current app, open Settings, or quit. The native macOS Settings window contains modifier keys, resize-button selection, window behavior, snapping controls, reset, and excluded-app management. Tile gaps and screen margins are configurable in the Snapping pane.

App exclusions use a bundle identifier when one is available and otherwise use the process name, which supports unbundled Wine and CrossOver processes.

## Requirements

- macOS 12 or later
- Accessibility permission for Jostle
- Xcode with the macOS SDK to build from source

Jostle prompts for Accessibility access on first launch. Relaunch it after granting access in System Settings.

## Build

```sh
xcodebuild \
  -project Jostle.xcodeproj \
  -scheme Jostle \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

The unsigned app is written to `build/Build/Products/Release/Jostle.app`. For regular local use, sign it with your Apple Development identity before copying it to `/Applications`.

## Test

```sh
xcodebuild \
  -project Jostle.xcodeproj \
  -scheme Jostle \
  -destination 'platform=macOS' \
  -derivedDataPath build-tests \
  CODE_SIGNING_ALLOWED=NO \
  test

swift test --package-path JostleCore
```

`JostleCore` contains deterministic geometry, event-routing, gesture, and settings policy. The app target contains the SwiftUI Settings scene plus AppKit, Core Graphics event-tap, Accessibility, and `UserDefaults` adapters.

## Settings

Settings are stored as one Codable document under `Jostle.settings` in Jostle's standard `UserDefaults` domain. Jostle is a new app and does not import settings from other applications.

## Project lineage

Jostle was inspired by and originally forked from Easy Move+Resize by Daniel Marcotte. The original copyright and MIT license are preserved in [`LICENSE.txt`](LICENSE.txt).

## Contributing

Issues and pull requests are welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md).
