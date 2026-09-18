# ADR 0001: Input customization runtime

- Status: Accepted for MVP
- Date: 2026-09-18

## Context

Jostle already owned one Core Graphics event tap for modifier-based window gestures and Focus Follows Pointer. The differentiated input MVP adds scroll-wheel transformation, physical extra-button routing, and per-device behavior. Installing a second independent tap would make ordering, cancellation, health reporting, and recovery ambiguous.

The MVP also needs conservative behavior: existing users must see no change until they opt in; unsupported or unattributed events must retain native behavior; and Keep Awake must remain independent of Accessibility and event-tap health.

## Decision

### One tap owner and a fixed pipeline

`EventTapController` remains the sole event-tap owner. Processing order is:

1. Recover a tap disabled by timeout or user input.
2. Ignore Jostle-tagged synthetic events.
3. Attribute the event to the most recent IOHID pointing device when possible.
4. Reverse scroll deltas when the resolved profile requires it.
5. Continue or finish an already-owned extra-button action.
6. Start an opted-in extra-button action.
7. Apply Jostle's existing modifier gesture and focus policies.
8. Pass through every unhandled event unchanged.

Synthetic keyboard events carry a private `eventSourceUserData` marker so Back/Forward mappings cannot recurse through the pipeline.

### Profile precedence

For scrolling and device focus, an exact stable device rule takes precedence over the mouse/trackpad category default. Existing per-application rules continue to decide whether Focus Follows Pointer is enabled; the input profile is an additional device gate rather than a replacement for app policy.

Unknown devices resolve to conservative defaults and do not receive an exact rule automatically.

### Stateful ownership

Move and resize actions are pinned to the physical button and resolved action captured on button-down. Configuration changes do not reroute an active down/drag/up stream. Matching button-up, `Escape`, session loss, tap failure, teardown, sleep, and termination clear owned interaction state and restore the original frame after cancellation when possible.

### Recovery and independence

Input customization is opt-in and has a separate menu toggle. Safe Mode disables input interception after repeated unclean launches, when launched with `--safe-mode`, or when Shift-Option is held during launch. Existing window controls remain available in automatic Safe Mode. Keep Awake never depends on Accessibility or the event tap.

For the MVP, the tap stays on Jostle's existing main run-loop source because window actions synchronously coordinate Accessibility state and AppKit feedback. Scroll mutation is bounded and allocation-light. Moving pure event transformation to a dedicated event thread is deferred until settings/device snapshots and main-actor window commands have a tested synchronization boundary; it must not be achieved by synchronously bouncing every event back to the main thread.

## Consequences

- Event ordering and runtime health have one authoritative owner.
- Default installations preserve native scrolling and side-button behavior.
- Exact device attribution is best-effort because CGEvent sender IDs are not guaranteed on every device; the manager uses a short recent-IOHID fallback.
- The MVP does not promise pointer acceleration, pointer speed, hardware DPI, high-resolution wheel modes, battery telemetry, or vendor protocols.
- Main-thread event-tap latency must be monitored. A dedicated transformation thread remains the next architectural hardening step if measurements show pressure.
