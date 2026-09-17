# Changelog

## 2026.9.0 — Unreleased

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
- Raise the minimum supported version to macOS 12.
- Replace binary-release automation with source build and test CI.
