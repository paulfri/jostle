# Input customization verification record

Status date: 2026-09-18

This record separates reproducible local evidence from matrix cases that require another OS, machine, device, application, or destructive fault injection. An unchecked external case is not treated as passing merely because its policy engine has unit coverage.

## Baseline environment

- Machine: `Mac17,7`, Apple silicon (`arm64`)
- macOS: 27.0
- Display: one Pro Display XDR at the time of verification
- Build: Jostle Development, bundle ID `fm.pau.jostle.development`
- Installed artifact: `~/Applications/Jostle Development.app`
- Xcode SDK/toolchain: macOS 27.0 / Xcode 27

This environment does not cover the minimum supported macOS release, intervening releases, Intel, or multi-display layouts.

## Automated evidence

| Check | Command | Result |
| --- | --- | --- |
| Core package suite | `swift test --package-path JostleCore` | 57 tests passed |
| App/adaptor suite | `xcodebuild test -project Jostle.xcodeproj -scheme 'Jostle Development' -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` | 67 tests passed |
| Release microbenchmarks | `swift test --package-path JostleCore -c release --filter InputPerformanceBaselineTests` | 100,000 iterations per path; policy 21 ns average, smoothing advance 74 ns average |
| Signed app build | `xcodebuild build -project Jostle.xcodeproj -scheme 'Jostle Development' -configuration Debug` | Passed with Apple Development signing |
| Installed signature | `codesign --verify --deep --strict --verbose=2 "$HOME/Applications/Jostle Development.app"` | Valid and satisfies designated requirement |
| Whitespace integrity | `git diff --check` | Passed |

The performance figures are regression indicators from optimized pure-core loops, not end-to-end latency claims. Their broad 50 µs test ceiling is intended to catch accidental blocking work, not define product latency.

Automated coverage includes profile precedence and migration, all Core Graphics scroll-delta representations, smoothing phases and cancellation, button interaction ownership, synthetic-event rejection, settings compatibility, isolated input backup/reset/import, invalid-backup non-mutation, terminal recovery arguments, diagnostics redaction, known-utility matching, runtime health policy, Keep Awake monotonic timing, and status presentation.

## Signed-app runtime evidence

A privacy-redacted report was previewed from **Settings → General → Diagnostics…** after ordinary signed-app use:

| Metric | Observed |
| --- | ---: |
| Event-tap callbacks | 73,324 |
| Callback average | 33.76 µs |
| Approximate p95 | ≤100 µs |
| Approximate p99 | ≤500 µs |
| Maximum | 1,976.62 µs |
| Disabled by timeout | 0 |
| Disabled by user input | 0 |

The tap was requested, operational, and applying input customizations. These observations are below ADR 0001's migration thresholds. The session did not produce representative smoothing-timer samples, so the required one-hour high-rate smoothing stress run remains open.

## Manual checks completed locally

- The signed development app launches from `~/Applications` and retains Accessibility/event-tap operation.
- General settings display startup, menu click behavior, battery presentation, Keep Awake icon presentation, diagnostics, and app-wide restore controls.
- The diagnostics preview appears before export and offers **Export…**, **Copy**, and **Close**.
- The report contains aggregate runtime state, tap-disable and Jostle-synthetic callback counters, and no device/application identity from configured rules (also enforced by tests).
- Settings promotion changes the process from background-only to a regular foreground app; closing Settings restores background-only menu-bar operation without terminating the process.
- The status process remains alive after Settings closes.
- An explicit `--safe-mode --show-settings` signed-app launch reported `safe_mode: yes` and `input_customizations_active: no`; the next normal launch reported `safe_mode: no` and restored `input_customizations_active: yes`, proving the bypass did not erase the enabled configuration.
- The refreshed General screenshot was captured from the signed development app.
- Command-Q closing Settings instead of the process, menu battery presentation, and status-click routing are covered both by prior signed-app smoke checks and focused app tests.

## Matrix cases still requiring external/manual evidence

### Operating systems and machines

- macOS 13 and every intervening supported major release
- latest public production macOS if different from the baseline above
- Intel hardware, if Intel remains a shipping target
- two/three displays, mirroring, rotation, Spaces, and mixed refresh rates

### Devices and transports

- built-in Apple trackpad and Magic Mouse/Magic Trackpad
- generic USB three-button and five-button mice
- a non-Logitech Bluetooth mouse
- Logitech Bluetooth, Bolt/Unifying receiver, and direct-USB combinations
- two identical devices simultaneously
- live hot-plug, receiver removal, sleep/wake, and low-battery transitions

### Applications and environments

- systematic AppKit, SwiftUI, Safari, Chromium, Electron, game, terminal, password/Secure Input, remote desktop, screen sharing, VM, full-screen, Mission Control, and Wine checks
- concurrent live runs of each warned utility; detector matching is automated, but interaction behavior must be checked with the actual products installed

### Fault injection and endurance

- revoke Accessibility during each active interaction
- force an actual event-tap timeout/invalidation, not only policy/recovery simulation
- remove a device between physical down and up
- switch app/display/profile during a physical held interaction
- corrupt the persisted input subsection independently of the outer settings document
- remove or corrupt a synthetic marker in a live event stream
- restart a future dedicated event thread during stateful work
- one-hour high-rate smoothing run and hardware-rate tests at 125/500/1,000/8,000 Hz where suitable hardware exists

Pointer-system and vendor-hardware mutation failure cases remain inapplicable because those features are explicitly deferred and issue no writes.
