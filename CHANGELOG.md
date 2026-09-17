# Changelog

## 0.1.0 — Unreleased

- Rebrand the project as Jostle.
- Rewrite the menu-bar application in native Swift.
- Add a pure Swift core for event routing, gesture reduction, geometry, settings, and menu policy.
- Store settings as one typed Codable document without legacy migration.
- Support per-app exclusions for Wine and other processes without bundle identifiers.
- Build the status menu programmatically without a XIB.
- Add deterministic core, gesture-contract, settings-store, and Core Graphics adapter tests.
- Raise the minimum supported version to macOS 12.
- Replace binary-release automation with source build and test CI.
