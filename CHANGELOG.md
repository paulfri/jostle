# Changelog

## 2026.9.3 — 2026-09-21

- Adopt an Icon Composer app icon that fills the macOS icon canvas without a nested system squircle.
- Add configurable Focus Follows Pointer with immediate or delayed activation.
- Replace global app exclusions with independent per-app rules for window controls and pointer focus in the new Apps settings tab.
- Add device-aware scrolling and button customizations with per-device and per-app profiles.
- Add a per-app **Reset modifiers when switching** compatibility control and discover Wine-hosted apps such as `eqgame.exe`.
- Add integrated Keep Awake sessions with preset durations, display-sleep control, lock pausing, battery deactivation, completion notifications, and configurable menu-bar indicators.
- Introduce Jostle's Calm frame identity across the app icon, menu bar, Settings, and Keep Awake state language.
- Add configurable menu-bar click behavior and a recordable global Keep Awake shortcut.
- Add `jostle:` automation URLs plus Set and Get Keep Awake actions for Shortcuts.
- Raise the minimum supported version to macOS 13 and use `SMAppService` exclusively for launch at login.

## 2026.9.2 — 2026-09-18

- Add the application runpath required to load Sparkle at launch.

## 2026.9.1 — 2026-09-18

- Use Control alone as the default activation modifier.
- Keep the required last modifier visually active in Settings instead of dimming its checkbox.
- Correct the spacing between the Resize with label and its button in General Settings.
- Add signed Sparkle updates, manual and opt-in automatic checks, and automated appcast publication.

## 2026.9.0 — 2026-09-17

- Rebrand the project as Jostle.
- Rewrite the menu-bar application in native Swift.
- Add a pure Swift core for event routing, gesture reduction, geometry, settings, and menu policy.
- Store settings as one typed Codable document without legacy migration.
- Support per-app exclusions for Wine and other processes without bundle identifiers.
- Replace the legacy dropdown with a compact menu and a native tabbed macOS Settings window.
- Build the status menu programmatically without a XIB.
- Add deterministic core, gesture-contract, settings-store, and Core Graphics adapter tests.
- Add edge and corner snapping with previews, restore-on-drag, and configurable spacing.
- Add modifier-double-click window actions and Escape gesture cancellation.
- Enforce minimum resize dimensions and show branded active-edge feedback.
- Recover from live Accessibility changes and disabled or invalid event taps.
- Report runtime health through actionable menu states and a dimmed status icon.
- Isolate local Debug builds as blue-branded Jostle Development with separate settings and Accessibility identity.
- Add CalVer, Developer ID signing, notarization, ZIP/DMG packaging, Gatekeeper verification, and checksums.
- Raise the minimum supported version to macOS 12.
- Replace binary-release automation with source build and test CI.
