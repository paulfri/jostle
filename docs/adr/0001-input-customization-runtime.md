# ADR 0001: Input customization runtime

- Status: Accepted for MVP
- Date: 2026-09-18

## Context

Jostle already owned one Core Graphics event tap for modifier-based window gestures and Focus Follows Pointer. The differentiated input MVP adds scroll-wheel transformation, physical extra-button routing, and per-device behavior. Installing a second independent tap would make ordering, cancellation, health reporting, and recovery ambiguous.

The runtime also needs conservative behavior: existing users must see no change until they opt in; unsupported or unattributed events must retain native behavior; and Keep Awake must remain independent of Accessibility and event-tap health. The LinearMouse migration adds ordered device/app/process scroll profiles, linear delta transforms, timer-driven smoothing, and optional standard Bluetooth battery reporting.

## Decision

### One tap owner and a fixed pipeline

`EventTapController` remains the sole event-tap owner. Processing order is:

1. Recover a tap disabled by timeout or user input.
2. Ignore Jostle-tagged synthetic events.
3. Attribute the event to its IOHID pointing device when possible.
4. Resolve ordered device-category, exact-device, app-bundle, and process-name scroll profiles.
5. Apply per-axis reverse, distance, acceleration, and speed transforms.
6. Feed opted-in smoothed axes to the smoothing engine, suppress those source deltas, and emit marked synthetic continuous-scroll events at 120 Hz.
7. Continue or finish an already-owned extra-button action.
8. Start an opted-in extra-button action.
9. Apply Jostle's existing modifier gesture and focus policies.
10. Pass through every unhandled event unchanged.

Synthetic keyboard and scroll events carry a private `eventSourceUserData` marker so they cannot recurse through the pipeline. Smoothing is cancelled on teardown, session loss, device disconnection, configuration changes observed on the next input, or a transition to a non-smoothed profile.

### Profile precedence

Legacy category and exact-device reverse settings form the scrolling baseline. Enabled scroll profiles are then evaluated in definition order. Every matching profile overrides only the values it specifies, so later matching profiles have final priority. A profile may combine device category or exact device with app bundle IDs or process names; bundle and process lists are alternatives within that profile.

For device focus, an exact stable device rule still takes precedence over the mouse/trackpad category default. Existing per-application rules continue to decide whether Focus Follows Pointer is enabled; the input profile is an additional device gate rather than a replacement for app policy.

Unknown devices resolve to conservative defaults and do not receive an exact rule automatically.

### Stateful ownership

Move and resize actions are pinned to the physical button and resolved action captured on button-down. Configuration changes do not reroute an active down/drag/up stream. Matching button-up, `Escape`, session loss, tap failure, teardown, sleep, and termination clear owned interaction state and restore the original frame after cancellation when possible.

### Recovery and independence

Input customization is opt-in and has a separate menu toggle. Safe Mode disables input interception after repeated unclean launches, when launched with `--safe-mode`, or when Shift-Option is held during launch. Existing window controls remain available in automatic Safe Mode. Keep Awake never depends on Accessibility or the event tap.

The tap stays on Jostle's existing main run-loop source because window actions synchronously coordinate Accessibility state and AppKit feedback. Scroll mutation is bounded; smoothing advances from a main-run-loop common-mode timer. Moving pure event transformation to a dedicated event thread is deferred until settings/device snapshots and main-actor window commands have a tested synchronization boundary; it must not be achieved by synchronously bouncing every event back to the main thread.

### Runtime measurements and thread boundary

Jostle records bounded, aggregate histograms for complete event-tap callback duration and smoothing-tick duration. The histograms contain only counts and elapsed monotonic time; they do not retain event contents, coordinates, keys, applications, device identifiers, or timestamps. A diagnostics report exposes sample count, average, approximate p95/p99, maximum, and tap-disable recovery counts. Metrics reset when the process exits.

Pure release-build baselines on an Apple-silicon `Mac17,7` running macOS 27.0 measured 100,000 iterations each:

| Path | Average |
| --- | ---: |
| `EventPolicy.intent` | 21 ns |
| `ScrollSmoothingEngine.advance` with periodic input | 74 ns |

Run `swift test --package-path JostleCore -c release --filter InputPerformanceBaselineTests` to reproduce the microbenchmarks. These figures are regression indicators, not end-to-end latency claims; Accessibility, AppKit, IOHID attribution, profile resolution, Core Graphics event mutation, and system load are represented only by runtime callback metrics.

A future dedicated serial event thread may own only:

- event adaptation and synthetic-event rejection;
- lookup against immutable settings and device snapshots;
- pure profile resolution, policy decisions, delta mutation, and smoothing state;
- ordered production of typed window/UI commands.

The main actor must continue to own settings mutation, `NSWorkspace`/AppKit UI, status presentation, Accessibility window queries and writes, and preview/feedback windows. Snapshot publication must be asynchronous and generation-tagged. Event processing must never synchronously dispatch to the main actor; typed commands must be delivered asynchronously while the event path immediately makes a fail-open/pass/suppress decision. Stateful button streams and smoothing ticks must remain serialized with source events, and cancellation must cross the boundary explicitly during tap teardown, sleep, session loss, device removal, and settings disablement.

Thread migration is warranted only after runtime evidence shows repeatable pressure (for example event-tap p99 above 2 ms, smoothing p99 above 1 ms, or any timeout-disable recovery attributable to Jostle), or before adding a feature known to perform unbounded work. It is complete only when ordering/cancellation contract tests, Thread Sanitizer, tap-disable recovery tests, and before/after end-to-end metrics pass without weakening fail-open behavior. Until then, moving threads would add synchronization risk without evidence of a user-visible gain.

### Battery support

Battery monitoring is independent of the event tap. When the selected display mode requires it, Jostle uses CoreBluetooth's public Battery Service (`180F`) and Battery Level characteristic (`2A19`), filters discoveries to names in the pointing-device inventory, and displays the selected percentage beside the menu bar icon with device details in the menu. Devices that do not expose the standard service are ignored; Jostle does not implement Logitech HID++ or another vendor protocol.

### Adapted smoothing implementation

The smoothing engine, preset coefficients, and portions of scroll transformation/delivery behavior are adapted from LinearMouse at revision `d82e98fba7f2b70c63f46f7444300336a96bd54e` under the MIT License. The source files retain attribution, and the complete file-level provenance and license are recorded in `THIRD_PARTY_NOTICES.md`, which is also bundled with the application.

## Consequences

- Event ordering and runtime health have one authoritative owner.
- Default installations preserve native scrolling and side-button behavior.
- Exact device attribution is best-effort because CGEvent sender IDs are not guaranteed on every device; the manager uses a short recent-IOHID fallback.
- Jostle does not promise pointer acceleration, pointer speed, hardware DPI, high-resolution wheel modes, or vendor-specific battery/protocol support.
- Standard Bluetooth battery readings are best-effort and absent when a device does not expose the public service.
- Main-thread event-tap latency and the 120 Hz smoothing timer must be monitored. A dedicated transformation thread remains the next architectural hardening step if measurements show pressure.
