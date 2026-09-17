# Jostle

Move and resize macOS windows by modifier-dragging anywhere inside them.

Jostle is a small native Swift menu-bar utility inspired by X11/Linux window managers and [Easy Move+Resize](https://github.com/dmarcotte/easy-move-resize).

> **Current status:** source-only preview. Binary releases are not published yet.

## Usage

The default modifier combination is **Command + Control**:

- **Left-drag** anywhere inside a window to move it.
- **Right-drag** anywhere inside a window to resize it.
- The resize direction is chosen from the region where the drag starts.

The menu bar menu can:

- Change the required modifier keys.
- Use middle-click instead of right-click for resizing.
- Raise a manipulated window to the front.
- Enable resize-only mode.
- Exclude individual apps and re-enable them later.
- Temporarily disable Jostle or reset its settings.

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

`JostleCore` contains deterministic geometry, event-routing, gesture, settings, and menu policy. The app target contains the AppKit, Core Graphics event-tap, Accessibility, and `UserDefaults` adapters.

## Settings

Settings are stored as one Codable document under `Jostle.settings` in Jostle's standard `UserDefaults` domain. Jostle is a new app and does not import settings from other applications.

## Project lineage

Jostle was inspired by and originally forked from Easy Move+Resize by Daniel Marcotte. The original copyright and MIT license are preserved in [`LICENSE.txt`](LICENSE.txt).

## Contributing

Issues and pull requests are welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md).
