# Input Customization Integration Plan

Status: differentiated MVP and active LinearMouse scrolling migration implemented; current roadmap reconciled below; broader pointer/hardware work remains proposed or explicitly deferred

Scope source: the five LinearMouse screenshots supplied for this design

Target: Jostle on macOS 13+

## Decision

Build the interaction features into Jostle as native subsystems; do **not** launch or bundle a second menu bar app.

The product thesis is narrower than LinearMouse parity: **Jostle turns a pointing device into a faster way to control windows and common desktop actions.** Device-aware window gestures, navigation, and Keep Awake integration are the differentiators. General-purpose pointer tuning, vendor protocols, and broad hardware control remain later compatibility work rather than MVP promises.

The integration should have:

1. one event-tap owner and an ordered event-transformation pipeline;
2. deterministic profiles for device, app, and display contexts;
3. pure policy and transformation engines in `JostleCore`;
4. macOS, HID, Accessibility, and vendor adapters in the app target;
5. conservative defaults, a fail-open event path, and a recovery mode;
6. staged delivery, with pointer-system and device-firmware writes gated behind compatibility spikes.

This preserves the goal—one app for window control, Keep Awake, and input customization—while keeping profile and interaction policy typed and testable and preserving a path to extract the tap runtime as later features demand it.

## Implemented differentiated MVP

The implemented input system includes:

- backward-compatible typed settings with opt-in defaults;
- IOHID device inventory, stable privacy-preserving identifiers, mouse/trackpad categorization, sender attribution, and a bounded recent-device fallback;
- per-axis reverse, automatic/line/pixel distance, speed, acceleration, smoothing, inertia, and bounce controls;
- ordered scroll profiles matched by device category, exact device, app bundle ID, and process name;
- a 120 Hz smoothing engine with marked synthetic events and touch/momentum phases;
- Button 4/5 mappings for universal Back/Forward, move, resize, maximize, left/right tile, next display, and Keep Awake;
- interaction pinning for button-held move/resize, synthetic-event tagging, Escape cancellation, and cleanup on disable, disconnect, session loss, sleep, tap teardown, and quit;
- per-device gating layered onto existing per-app Focus Follows Pointer policy;
- opt-in per-app Command-key recovery that waits for physical modifiers to clear and posts a balanced sequence only to the activated process;
- optional read-only battery reporting through the public Bluetooth Battery Service for supported pointing devices;
- one menu-bar item with configurable click behavior, a vector state icon, optional pointing-device battery text, an Input settings pane with ordered profile editing, disconnected-device overrides, crash-loop Safe Mode, `--safe-mode`, and Shift-Option launch recovery;
- a one-time importer for the supported subset of an existing LinearMouse configuration;
- a General settings pane for startup, menu-bar behavior, battery presentation, and icon presentation;
- a transient Dock presence while Settings is open, with menu-bar-only behavior restored on close and Command-Q closing Settings without terminating Jostle;
- unit coverage for profile precedence, migration/default behavior, smoothing phases, scroll transforms, button interaction routing, side-button persistence, battery menu behavior, status presentation, and every Core Graphics scroll-delta representation.

Jostle deliberately does **not** implement pointer acceleration/speed, hardware DPI, Logitech high-resolution wheel mode, or vendor protocols. The existing main-run-loop tap remains the owner; a dedicated transformation thread is deferred until immutable settings/device snapshots and main-actor window commands have a measured, tested boundary. See [ADR 0001](adr/0001-input-customization-runtime.md).

## Current roadmap priorities

### Completed hardening

- Added bounded aggregate runtime histograms for event-tap callbacks and 120 Hz smoothing ticks, release-build microbenchmarks, tap-disable/synthetic-event counters, and an evidence-gated immutable-snapshot/main-actor boundary in [ADR 0001](adr/0001-input-customization-runtime.md). Current evidence does not justify the synchronization risk of a thread migration.
- Added a user-previewed privacy-redacted diagnostics export and live non-blocking warnings for known concurrent input utilities.
- Added versioned, validated, isolated input reset/export/import plus persistent disable/reset launch arguments.
- Added operator documentation for support boundaries, privacy, conflicts, troubleshooting, backup, and terminal/Safe Mode recovery; refreshed the General screenshot.

### Now — complete external validation

1. Collect end-to-end runtime diagnostics under ordinary use and a one-hour high-rate smoothing stress run; move transformation work to a dedicated thread only if the ADR's measured thresholds are crossed.
2. Complete the remaining supported macOS, hardware, application, multi-display, Secure Input, remote-session, and failure-injection matrix identified in the [verification record](input-customization-verification.md) on environments actually available to the team.
3. Expand screenshot/UI/accessibility smoke coverage beyond the refreshed General pane.

### Next — complete the differentiated software feature set

- modifier-key scroll actions and source-app bypass controls;
- a broader typed button action catalog and recorder;
- primary/secondary swap, click debouncing, auto-scroll, and gesture-button interactions;
- pointer-to-scroll redirection with an always-available cancellation path;
- display-aware profile matching and effective-value/source presentation.

### Later — guarded system and hardware capabilities

- pointer acceleration and speed only after supported-OS API and restoration evidence exists;
- vendor-provider architecture, supported-device matrix, hardware DPI, and high-resolution wheel controls;
- vendor-specific battery protocols with freshness and unavailable/stale states.

### Explicitly deferred

- persistent Dock mode and menu-bar hiding are not current commitments; Jostle presently shows a Dock icon only while Settings is open and always retains its status item;
- the sidebar/context-bar settings redesign is deferred until Pointer, Buttons, or display-context destinations make the current toolbar materially insufficient;
- arbitrary shell-command actions, exclusive HID seizure, cloud sync, and telemetry remain out of scope.

## What “all this” includes

| Screenshot area | Capability | Jostle today | Integration disposition |
| --- | --- | --- | --- |
| Pointer | Disable pointer acceleration | No | Add after an API/OS compatibility spike |
| Pointer | Convert pointer movement to scroll events | No | Add as an advanced, default-off transformer |
| Pointer | Acceleration, speed, and hardware DPI | No | Add typed settings; gate hardware writes by capability |
| Scrolling | Independent vertical/horizontal configuration | Yes | Implemented with ordered contextual profiles |
| Scrolling | Reverse scrolling | Yes | Implemented by category, exact device, app, and process context |
| Scrolling | High-resolution wheel | No | Add only for positively identified supported devices |
| Scrolling | Smoothed scrolling, response, speed, acceleration, inertia, bounce | Yes | Implemented with a deterministic engine and synthetic-event loop protection |
| Scrolling | Modifier-key scroll actions | No | Add exact-modifier mappings with a “system default” fallback |
| Buttons | Universal back/forward | Yes | Implemented with app-compatible side-button translation |
| Buttons | Swap primary and secondary buttons | No | Add while preserving balanced down/drag/up streams |
| Buttons | Click debouncing | No | Add after contract tests for click/drag correctness |
| Buttons | Auto-scroll | No | Add as an advanced stateful interaction |
| Buttons | Gesture button | No | Add after the basic mapping engine |
| Buttons | Assign actions to mouse buttons/wheel | No | Add a recorder and typed action catalog |
| App compatibility | Clear a stuck Command key after switching | Yes | Implemented as an opt-in per-app recovery action, process-targeted and gated by Input Customizations and Safe Mode |
| General | Menu bar visibility | Always visible | Persistent hiding is explicitly deferred; recovery paths remain available through reopen-to-Settings and Safe Mode |
| General | Current device battery | Partial | Public Bluetooth Battery Service implemented; vendor-specific devices remain unsupported |
| General | Dock visibility | Visible only while Settings is open | Runtime activation-policy switching is implemented; persistent Dock mode is deferred |
| General | Start at login | Yes | Implemented through `LoginItemController` in General settings and the status menu |
| General | Show pointer location | No | Add a non-activating overlay and configurable trigger |
| General | Bypass events generated by other apps | No | Add source attribution and Jostle synthetic-event tagging |
| General | Version and update controls | Yes | Keep the existing Sparkle integration |
| General | Export logs / support links | Partial | Privacy-redacted diagnostics preview/copy/export is implemented; support links remain product configuration |
| Menu | Batteries, Settings, Config, login, current-app configuration, quit | Partial | Battery summary, configurable click behavior, Settings, login, current-app toggles, and quit are integrated; full profile-context configuration remains later work |

The screenshots are a feature reference, not a requirement to copy LinearMouse’s layout, terminology, defaults, or implementation.

## Boundaries

### In scope

- Mouse and trackpad pointer/scroll/button customization.
- Per-device, per-app, and per-display selection.
- Device inventory and optional battery/capability reporting.
- One settings window and one menu bar item for all Jostle features.
- Compatibility, recovery, diagnostics, migration, and test work needed to ship safely.

### Not in the first release

- Arbitrary shell-command actions. They expand the threat model and are not required by the screenshots.
- Exclusive HID device seizure.
- Claiming support for a device capability based only on vendor/product name.
- Repeated or destructive import of another app’s configuration. Jostle performs one non-destructive supported-subset migration when no scroll profiles exist.
- Private or unstable APIs in a release build without an explicit owner decision, documented fallback, and supported-OS test evidence.
- Cloud sync or telemetry.

## Current architecture findings

Jostle is already well positioned for this work:

- `EventTapController.swift` owns a `cghidEventTap`, window gestures, focus-follows-pointer, and tap recovery; `CommandKeyRecoveryController.swift` separately handles process-targeted recovery after app activation.
- `JostleCore` contains deterministic event policy, geometry, gesture, snapping, Keep Awake, and settings behavior with focused tests.
- `SettingsStore` persists one backward-compatible Codable document.
- `AppDelegate` composes long-lived controllers.
- Settings use an `NSTabViewController` with SwiftUI panes for General, Gestures, Input, Keep Awake, Snapping, Applications, and Updates.
- Keep Awake is intentionally independent of Accessibility and should remain so.

The main constraints are:

- The event tap and current 120 Hz smoothing timer run on the main run loop. Their latency must be measured before adding higher-rate pointer transformation.
- `EventTapController` is already responsible for several window behaviors. It should become a consumer of a shared input service, not absorb all new transformations.
- `JostleSettings` is a flat structure. Adding dozens of input fields directly would make migration and profile inheritance fragile.
- The current toolbar remains suitable for the implemented panes, but it will not scale to separate Pointer/Scrolling/Buttons destinations plus device/app/display context selectors; defer a sidebar migration until those destinations are approved.

## Proposed architecture

```text
AppDelegate
├── InputRuntimeController
│   ├── EventTapService             future evidence-gated dedicated event thread
│   ├── EventRouter                 context resolution + interaction pinning
│   ├── EventTransformerPipeline    ordered, fail-open transforms
│   ├── DeviceService               IOHID inventory on its own queue
│   ├── DeviceCapabilityRegistry    generic + vendor-specific providers
│   ├── SystemPointerController     guarded system-setting mutations
│   └── InputDiagnostics
├── WindowInteractionController     current move/resize/snap/focus behavior
├── KeepAwakeController             remains independent
├── SettingsStore
└── StatusMenuController

JostleCore
├── InputProfileResolver
├── InputEvent / OutputEvent models
├── PointerPolicy
├── ScrollTransformEngine
├── SmoothedScrollEngine
├── ButtonMappingEngine
├── ClickDebounceEngine
├── StatefulInteractionRouter
└── Settings validation + migration
```

### 1. One event tap, evidence-gated dedicated thread

The current measured implementation retains direct main-run-loop ownership in `EventTapController`; [ADR 0001](adr/0001-input-customization-runtime.md) defines the immutable snapshot/main-actor boundary and migration thresholds. If those thresholds are crossed, replace direct ownership with `EventTapService`:

- Install one `.cghidEventTap` at `.headInsertEventTap`.
- Run it on a dedicated `Thread`/`CFRunLoop` with `.userInteractive` quality of service.
- Publish immutable settings/profile snapshots to that thread atomically.
- Keep UI, `NSWorkspace`, and SwiftUI work off the callback path.
- Re-enable after `.tapDisabledByTimeout` and `.tapDisabledByUserInput` when appropriate.
- Health-check validity and expose one runtime status to the menu.
- Pass the original event through on unknown input, missing context, adapter failure, or disabled features.

The callback must do bounded work. No disk I/O, device enumeration, process inspection, synchronous main-thread calls, or unbounded logging is allowed on the event thread.

### 2. Ordered transformation pipeline

Recommended order:

1. capture immutable event metadata and source/device/context;
2. reject or bypass Jostle-generated and optionally other-app-generated events;
3. deliver continuations to the route that owns an active interaction;
4. normalize physical device input, including supported high-resolution wheels;
5. apply primary/secondary swap so later stages see logical buttons;
6. convert pointer movement to a logical scroll event when that advanced mode is active;
7. apply reverse scrolling so wheel mappings use the user-visible direction;
8. arbitrate Jostle’s exact-modifier window gestures before general button mappings;
9. resolve high-priority stateful interactions (auto-scroll and gesture button);
10. resolve explicit button/wheel mappings;
11. apply modifier-key scroll actions;
12. apply linear scroll speed/acceleration;
13. apply smoothed scrolling and scheduled momentum output;
14. let focus-follows-pointer observe only surviving pointer movement;
15. return, replace, suppress, or defer the result.

Deferred events resume at the stage after the transformer that created them, rather than starting the pipeline again. The exact order becomes a versioned behavioral contract. A later reorder is a behavior change and requires contract-test updates.

### 3. Synthetic-event ownership

Every event Jostle posts must carry a private marker in a suitable event field. The pipeline must recognize that marker and avoid transforming the event again, except for an explicit continuation stage. This prevents:

- smoothed scrolling feeding itself;
- remapped buttons recursively remapping;
- pointer-to-scroll output re-entering scroll transforms;
- action-generated shortcuts triggering their own mapping.

Events generated by other processes are separate. When “bypass events from other apps” is on, pass them unchanged unless they are continuations of an interaction Jostle already owns. Never drop a matching release merely because the source or active profile changed.

### 4. Stateful interaction pinning

A mouse down, chord, long press, drag, gesture, held shortcut, or smoothing tail can outlive the profile that began it. Pin each claimed interaction to its original transformer route until it drains.

On disable, permission loss, sleep, session resignation, device removal, or app termination:

- cancel timers;
- emit required key/button releases;
- cancel gesture phases cleanly;
- clear retained route state;
- restore guarded hardware/system settings.

This is required to prevent stuck mouse buttons, stuck modifier keys, orphaned drags, and momentum continuing in the wrong app.

### 5. Device service

`DeviceService` should use IOHID only for inventory, identity, input attribution support, capabilities, and explicitly supported hardware features. It runs on a queue separate from the event thread.

A stable device key should prefer:

1. transport + vendor ID + product ID + stable serial;
2. transport + vendor ID + product ID + stable location identity;
3. vendor ID + product ID with an explicit “identical devices may share this profile” limitation.

Do not persist transient registry IDs as the only identity. Model capability availability explicitly:

```swift
enum DeviceCapabilityStatus<Value> {
    case unsupported
    case unavailable(reason: String)
    case available(Value)
}
```

The UI should hide or explain unsupported DPI, high-resolution wheel, and battery controls rather than showing toggles that do nothing.

### 6. System and hardware mutation boundary

Pointer acceleration/speed and hardware DPI may require settings or device writes rather than ordinary event transforms. Isolate these behind `SystemPointerController` and vendor capability providers.

Before the first mutation, record a restoration ledger containing:

- stable device/context key;
- parameter name;
- observed baseline;
- value last written by Jostle;
- timestamp and app version;
- pending-restoration state.

Restoration must be compare-and-swap: restore the baseline only if the current value still equals the last value written by Jostle. If another app or the user changed it, do not overwrite that newer choice.

Reconcile on profile changes, feature disable, device reconnect, wake, session switch, clean termination, and next launch after an unclean exit. Hardware writes must be clamped, capability-checked, idempotent, rate-limited, and never issued from the event callback.

A release gate must verify the actual APIs and semantics on every supported macOS family. If reliable restoration or per-device behavior cannot be demonstrated, label the control experimental or omit it.

## Configuration model

Keep existing settings fields compatible. Add one nested, versioned input document rather than flattening every new value into `JostleSettings`.

```swift
struct JostleSettings: Codable, Equatable, Sendable {
    // Existing fields remain decodable.
    var input: InputCustomizationSettings
}

struct InputCustomizationSettings: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var isEnabled: Bool
    var profiles: [InputProfile]
    var general: InputGeneralSettings
}

struct InputProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var match: InputProfileMatch
    var pointer: PointerSettingsPatch
    var scrolling: ScrollingSettingsPatch
    var buttons: ButtonSettingsPatch
}

struct InputProfileMatch: Codable, Hashable, Sendable {
    var device: DeviceMatch?
    var application: ApplicationMatch?
    var display: DisplayMatch?
}
```

Contextual fields use an explicit inherited/value representation. Do not overload `false`, zero, or a missing key to mean multiple things.

### Profile precedence

Resolve effective settings in this documented order:

1. safe built-in defaults;
2. global user profile;
3. device-category profile;
4. exact-device profile;
5. application profile;
6. display profile;
7. the exact device + application + display combination.

Within one level, reject duplicate match keys during validation rather than depending on array order. The settings UI must show both the effective value and its source, for example “0.68 — inherited from MX Master 3S.”

Application identity should reuse Jostle’s bundle-ID-first behavior and its name fallback for Wine/non-bundled processes. Display matching needs a stable identifier strategy plus a human-readable name; display names alone are not sufficient when two monitors are identical.

### Validation

Clamp and validate at decode and mutation boundaries:

- all numeric ranges are finite and documented;
- smoothing presets produce stable coefficients;
- no duplicate mapping triggers in one effective profile;
- a trigger cannot map to itself recursively;
- held actions always have a release path;
- DPI/high-resolution wheel values require a matching capability;
- at least one recovery path remains visible when menu and Dock modes change;
- unknown future enum cases decode safely or disable only the affected feature.

Malformed input settings must not discard unrelated Jostle window or Keep Awake settings. Preserve the invalid document for diagnostics and fall back only the invalid input section.

## UI and information architecture

### Options considered

1. **Toolbar tabs — current** — native and appropriate for the implemented General, Gestures, Input, Keep Awake, Snapping, Applications, and Updates destinations, but not scalable to several additional context-heavy panes.
2. **Category sidebar with a context bar — future recommendation** — familiar macOS utility layout, scalable, and keeps device/app/display context visible.
3. **Profile-first editor** — most powerful for experts but makes common changes feel like rule programming.

Keep option 1 for the current feature set. Adopt option 2 only when approved Pointer, Scrolling, Buttons, or display-aware destinations require it; do not churn the settings shell solely to match this planning document.

### Future sidebar target

```text
WINDOWS
  Gestures
  Snapping

INPUT
  Pointer
  Scrolling
  Buttons

AUTOMATION
  Applications
  Keep Awake

JOSTLE
  General
  Updates
```

Pointer, Scrolling, and Buttons show a compact context bar:

```text
[ MX Master 3S ▾ ]  [ All Apps ▾ ]  [ All Displays ▾ ]
```

Rules:

- “All …” edits the inherited layer; a concrete selection edits that context.
- Clearly distinguish “Use inherited value” from an explicit on/off value.
- Show disconnected saved devices without pretending they are currently available.
- Disable unsupported controls with a short reason and capability detail.
- Put “Restore this profile” beside the profile context, not as an ambiguous app-wide reset.
- Keep Jostle’s existing accent, native typography, standard controls, and restrained density.
- Use SF Symbols or existing assets; do not copy LinearMouse artwork.
- Support keyboard navigation, VoiceOver labels, reduce motion, increased contrast, and light/dark appearances.

### Menu design

Keep the status menu operational even when input customization fails:

```text
Jostle status / optional device battery summary
Input Customizations Enabled        ✓
Window Features Enabled             ✓
Keep Mac Awake …
Configure Current Context           >
Start at Login                      ✓
Settings…
Check for Updates…
Quit Jostle
```

“Configure Current Context” opens Pointer/Scrolling/Buttons with the last active device, frontmost app, and display preselected. Battery rows appear only for identified devices with fresh readings and include a stale/unavailable state when necessary.

Window features and input customizations must have independent toggles. Keep Awake remains available without Accessibility permission or an operational event tap.

The General pane owns app-wide status presentation: left-click can either open the menu or toggle Keep Awake, right-click performs the complementary action, pointing-device battery text can be never/low-only/always, and Keep Awake indicator styling remains configurable. While Settings is visible Jostle temporarily becomes a regular Dock app; closing Settings or pressing Command-Q closes only Settings and restores menu-bar-only accessory mode. The explicit **Quit Jostle** command still terminates the process.

## Safety, privacy, and compatibility requirements

### Recovery paths

Ship all of these before any event-suppressing customization:

- Menu item: **Disable Input Customizations**.
- Launch arguments: `--safe-mode` bypasses input for one launch, `--disable-input-customizations` persistently disables it while preserving profiles, and `--reset-input-customizations` resets only input settings.
- Launch gesture: hold Shift+Option while launching to enter safe mode.
- Reopen behavior: launching Jostle while it is already running presents Settings.
- Crash-loop guard: repeated unclean launches automatically disable input customization and explain why.
- A documented terminal recovery command.
- “Reset Input Customizations” does not erase window, Keep Awake, login, or update settings.

### Conflict handling

At launch and when enabling input customization, detect known concurrently running input utilities where practical (for example LinearMouse, SteerMouse, BetterMouse, USB Overdrive, Logi Options+, and relevant Karabiner components). Show a non-blocking compatibility warning; never terminate or modify another app.

The event path must remain deterministic if another event tap is present, but Jostle should recommend enabling transformations in only one utility. Add a diagnostics field for event-tap health and observed repeated synthetic input without recording user content.

### Permissions

- Reuse the existing Accessibility explanation and health flow.
- Probe actual capability rather than inferring permission from a preference alone.
- Explain why event observation/modification is needed before opening System Settings.
- Do not request Screen Recording.
- If a future device feature requires a different permission, request it only when that feature is enabled.
- Test Secure Input scenarios and fail open when keyboard events are unavailable.

### Privacy and diagnostics

- No input content, typed keys, pointer trails, window titles, or scroll history is persisted.
- Use unified logging with privacy annotations and bounded rates.
- Exported diagnostics redact device serials, usernames, process paths, app context, and display serials by default.
- Let the user preview the export.
- Battery polling is local and rate-limited.
- No telemetry is added by this project.

### Upstream responsibility

LinearMouse is an MIT-licensed behavioral and architectural reference. Jostle should initially implement its own small interfaces around Jostle’s existing architecture. If source is reused later:

- pin and record the upstream commit;
- preserve MIT copyright/license notices in reused files;
- add a third-party notices document;
- audit transitive package and embedded-code licenses;
- document local modifications and an upstream update process;
- do not copy names, artwork, screenshots, or trade dress.

References:

- [LinearMouse repository and MIT license](https://github.com/linearmouse/linearmouse)
- [LinearMouse configuration behavior](https://github.com/linearmouse/linearmouse/blob/main/Documentation/Configuration.md)
- [Apple event monitoring overview](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)
- [Apple IOHIDManager API](https://developer.apple.com/documentation/iokit/iohidmanager_h)

## Delivery plan and implementation checklist

A phase is complete only when its exit criteria pass. Do not hide incomplete risk work behind a disabled UI toggle. Checked items are complete in the current codebase. Unchecked items remain open; a **Partial** note records useful shipped work without claiming the full item or phase is done.

### Phase 0 — behavior, API, and licensing spikes

- [x] Write an ADR accepting the one-tap pipeline, profile precedence, fail-open policy, current main-run-loop ownership, measured migration thresholds, and the future immutable-snapshot/main-actor thread boundary.
- [ ] Capture a behavior specification for every control in the screenshots, including units, ranges, defaults, inheritance, and reset semantics. **Partial:** implemented scroll and button controls have typed defaults and tests; unimplemented controls still lack complete behavior contracts.
- [ ] Prototype pointer acceleration/speed changes on macOS 13 and the newest supported macOS; record public/private API use and restoration behavior.
- [ ] Prototype event-to-device attribution for USB, Bluetooth, Apple trackpad, and receiver-connected mice. **Partial:** IOHID inventory, sender attribution, exact-device identity, category fallback, and composite-keyboard rejection are implemented; the full transport/device matrix is not verified.
- [x] Prototype synthetic-event tagging and confirm no recursion through Jostle’s own tap.
- [ ] Prototype primary-button swap and prove balanced down/drag/up output.
- [ ] Prototype smooth-scroll output at 120 Hz without tap timeouts or main-thread work. **Partial:** 120 Hz output, phases, cancellation, and recursion protection are implemented, but output still runs on the main run loop and lacks the required stress evidence.
- [x] Determine whether Dock visibility changes safely at runtime or requires relaunch. Runtime switching is used while Settings is open and restores accessory mode without relaunch.
- [x] Audit LinearMouse source/dependencies before any code reuse and create `THIRD_PARTY_NOTICES.md` if reuse occurs.
- [ ] Decide the supported Logitech connection/device matrix before promising DPI, wheel, or battery support.

**Exit:** written evidence identifies a supportable API for each Phase 5/6 feature, or that feature is explicitly deferred.

### Phase 1 — foundations with no behavior change

- [x] Add `InputCustomizationSettings` with schema versioning and backward-compatible decoding.
- [x] Add a guarded, one-time, non-destructive importer for the supported subset of an existing LinearMouse configuration.
- [x] Add isolated reset/export/import operations for the input section.
- [ ] Implement deterministic profile matching, precedence, inheritance, validation, and effective-value/source reporting in `JostleCore`. **Partial:** ordered category, exact-device, bundle-ID, and process-name profile matching is implemented; display matching, duplicate-key rejection, and effective source reporting remain open.
- [ ] Add profile resolver tests for global, category, device, app, display, combination, duplicate, and missing-device cases. **Partial:** global/category/device/app/process precedence and unresolved-device migration are covered; display and duplicate-match contracts remain open.
- [ ] Extract event-tap lifecycle into `EventTapService` on a dedicated event thread.
- [ ] Adapt current window gesture and focus behavior to the shared service without changing its observable behavior.
- [ ] Add tap timeout/invalidation recovery tests and runtime diagnostics. **Partial:** timeout/user-disable recovery, runtime health, bounded callback/smoothing histograms, disable/synthetic counters, and privacy-redacted preview/export are implemented and covered; direct event-tap invalidation injection remains open.
- [x] Add synthetic-event markers and loop-prevention tests.
- [x] Implement safe mode, launch gesture, reopen-to-settings, crash-loop guard, and independent subsystem toggles.
- [x] Add automated tests proving legacy and current settings documents decode to compatible effective behavior.

**Exit:** existing Jostle controls pass all tests and manual smoke checks through the new event service; input customization remains off by default.

### Phase 2 — settings shell and device inventory

- [ ] Replace toolbar tabs with the sidebar settings shell. **Deferred:** retain the current toolbar until additional context-heavy destinations justify the migration.
- [x] Preserve all current General, Gestures, Input, Snapping, Applications, Keep Awake, and Updates behavior in the current settings shell.
- [ ] Add the device/app/display context bar and inherited-value presentation.
- [x] Provide ordered contextual scroll-profile editing for device category, exact device, app bundle ID, and process name.
- [x] Show connected and disconnected saved pointing devices, category defaults, per-device overrides, and override deletion.
- [ ] Implement `DeviceService` identity, connect/disconnect, sleep/wake, and stale-device handling. **Partial:** `PointingDeviceManager` provides IOHID identity, attribution, connect/disconnect, and disconnected saved-device presentation; the proposed standalone service and complete lifecycle matrix remain open.
- [ ] Add display identity and frontmost-application snapshots outside the event callback.
- [ ] Show capability states without enabling hardware writes. **Partial:** unsupported vendor controls are omitted and standard Bluetooth battery support is conservative, but a general capability-state UI is not implemented.
- [ ] Add keyboard navigation, VoiceOver labels, contrast, reduce-motion, and appearance checks.
- [ ] Add screenshot/UI smoke coverage for every settings destination and empty/disconnected state. **Partial:** a General-pane screenshot exists and disconnected devices are represented; systematic UI coverage remains open.

**Exit:** profiles can be created and edited against stable contexts, with unsupported capabilities represented honestly.

### Phase 3 — scrolling MVP

- [x] Implement vertical and horizontal reverse scrolling as a pure `JostleCore` transform.
- [x] Implement bounded linear speed and acceleration transforms.
- [x] Implement per-axis automatic/line/pixel distance transforms and editing.
- [ ] Implement exact modifier-key actions with system-default fallback.
- [x] Preserve untouched axes and all relevant scroll metadata, including integer, fixed-point, and point deltas.
- [ ] Add source-app bypass behavior and tests.
- [ ] Add fixtures for discrete wheels, continuous trackpads, diagonal scrolling, momentum, and zero-delta events. **Partial:** smoothing phase, axis suppression, re-engagement, and Core Graphics delta representation tests exist; the complete device fixture set remains open.
- [ ] Verify Safari, Chromium, Electron, AppKit, SwiftUI, and remote-desktop apps.
- [x] Verify no transformation of Jostle synthetic events.

**Exit:** default-off scrolling settings are deterministic, reversible immediately, and do not regress native trackpad gestures.

### Phase 4 — basic buttons

- [ ] Implement primary/secondary swap with complete down/drag/up stream remapping.
- [x] Implement universal back/forward with app-compatible side-button translation and persistence tests.
- [ ] Define the complete typed action catalog. **Partial:** system default, Back/Forward, move, resize, maximize, left/right tile, next display, and Keep Awake actions are implemented for Buttons 4/5.
- [ ] Build a button/wheel recorder that never captures typed text.
- [ ] Reject duplicate or recursive mappings in one effective profile.
- [ ] Implement press, release, short press, repeat, and hold lifecycles where the chosen action requires them. **Partial:** click actions and button-held move/resize lifecycles are implemented; repeat/long-press and the broader catalog remain open.
- [ ] Pin active mappings across profile/app/display/device changes. **Partial:** implemented button-held interactions remain pinned across settings, app, interruption, and device changes; display-context routing is not implemented.
- [x] Cancel implemented held interactions and smoothing output on disable, disconnect, sleep, session change, tap teardown, and quit.
- [x] Add gesture and interaction-sequence contract coverage in `GestureContractTests`, `EventPolicyTests`, and app-adapter tests.

**Exit:** mappings cannot leave a button or modifier stuck in fault-injection tests.

### Phase 5 — advanced scrolling and buttons

- [ ] Implement smoothed-scroll math with an injected monotonic clock. **Partial:** deterministic math consumes explicit monotonic timestamps and is covered by focused tests; a dedicated clock abstraction/event thread is not implemented.
- [x] Add presets plus response, speed, acceleration, inertia, and bounce controls with validated ranges.
- [ ] Schedule output on the event thread; cancel phases/timers cleanly. **Partial:** phase/timer cancellation is implemented, but scheduling remains on the main run loop.
- [ ] Implement click debouncing with explicit modes and drag-safe release handling.
- [ ] Implement auto-scroll with cancellation by Escape, click, profile disable, and device loss.
- [ ] Implement gesture-button recognition with documented thresholds and movement dead zones.
- [ ] Implement pointer-to-scroll redirection with an always-available cancellation path.
- [ ] Test chord/long-press/gesture ambiguity and deterministic winner selection.
- [ ] Run latency and CPU benchmarks at 125, 500, 1,000, and 8,000 Hz input rates where hardware permits.

**Exit:** event callback p95 is under 1 ms and p99 under 2 ms on the agreed baseline Mac, there are no event-tap timeouts in a one-hour stress run, and idle overhead meets the agreed release budget.

### Phase 6 — pointer settings and guarded mutations

- [ ] Implement `SystemPointerController` only with the Phase 0 approved mechanism.
- [ ] Add system/default, disabled/linear, and custom acceleration semantics without ambiguous zero values.
- [ ] Add pointer speed with explicit units/range and a reset-to-observed-system-default action.
- [ ] Implement the persistent restoration ledger and compare-and-swap restoration.
- [ ] Reconcile changes on app/display/profile switches without excessive writes.
- [ ] Restore safely after crash, relaunch, wake, reconnect, and permission loss.
- [ ] Detect unsupported Apple/OS/device combinations and disable controls with an explanation.
- [ ] Verify Jostle does not overwrite a concurrent user or third-party setting change.

**Exit:** every supported OS/device pair passes apply, switch, disable, quit, forced-crash, reboot/relaunch, and third-party-change restoration tests.

### Phase 7 — vendor capabilities and batteries

- [ ] Define a vendor capability provider protocol separate from generic device inventory. **Partial:** battery monitoring is protocol-backed and isolated, but no vendor capability registry exists.
- [x] Implement conservative read-only monitoring for devices exposing the public Bluetooth Battery Service, without sending vendor commands.
- [ ] Implement high-resolution wheel only for proven device/transport combinations.
- [ ] Implement hardware DPI with model-specific bounds, idempotence, rate limiting, and restoration.
- [ ] Implement read-only battery state with freshness timestamps and unavailable/stale states. **Partial:** CoreBluetooth public Battery Service readings, menu details, and configurable percentage presentation are implemented; freshness and explicit stale/unavailable states are not.
- [ ] Cover Bluetooth, receiver, direct USB, sleep/wake, receiver removal, and duplicate-device cases. **Partial:** standard Bluetooth connect/disconnect behavior exists; receiver, USB, duplicate-device, and full lifecycle verification remain open.
- [ ] Keep vendor failures isolated from generic event processing.
- [ ] Document the supported-device matrix in the README and UI. **Partial:** [input-customization.md](input-customization.md) documents generic IOHID and standard Bluetooth support plus explicit exclusions; vendor-specific UI/matrix work remains deferred.

**Exit:** unsupported devices receive no vendor commands, and all vendor features degrade to ordinary input without affecting window controls or Keep Awake.

### Phase 8 — General pane, menu, diagnostics, and release

- [x] Add a General pane for startup, menu-bar click behavior, battery presentation, Keep Awake icon presentation, and app-wide reset.
- [x] Add configurable left/right status-item click behavior while preserving an always-available menu action.
- [x] Render the status frame as a resolution-independent square with a legible monochrome Keep Awake state symbol.
- [ ] Add menu bar visibility only after reopen and recovery behavior is proven. **Deferred:** the status item remains always visible.
- [x] Show a Dock icon only while Settings is open, restore accessory mode on close, and make Command-Q close Settings without terminating the menu-bar process.
- [ ] Add pointer-location overlay with multi-display and accessibility testing.
- [ ] Integrate battery summary and current-context configuration into the status menu. **Partial:** fresh available battery readings and current-app toggles are integrated; full device/app/display profile-context configuration is not.
- [x] Add privacy-redacted diagnostics export with user preview, aggregate timing metrics, and no event content.
- [x] Add compatibility warnings for concurrently running input utilities.
- [ ] Update onboarding and Accessibility explanation.
- [x] Update README, General screenshot, privacy statement, support boundaries, troubleshooting, backup, and recovery instructions.
- [ ] Run the full manual matrix below. **Partial:** the signed-app baseline, automated suites, runtime callback evidence, and unavailable external cases are recorded in [input-customization-verification.md](input-customization-verification.md).
- [ ] Beta with input customization opt-in and collect explicit bug reports, not telemetry.
- [ ] Keep a remote rollback path through Sparkle and preserve settings when downgrading where possible.

**Exit:** release checklist is signed off with no P0/P1 input-loss, stuck-input, restoration, permission, or crash defects.

## Required test matrix

The current local evidence and explicitly unavailable environments are recorded in [input-customization-verification.md](input-customization-verification.md). A local pass does not close an external hardware or OS row.

### macOS and machines

- [ ] macOS 13 minimum supported version.
- [ ] Every intervening major version available to the team.
- [ ] Latest public macOS update.
- [ ] Apple silicon; Intel if Jostle continues to ship/support it.
- [ ] One, two, and three displays; mirrored and rotated display cases.

### Input devices

- [ ] Built-in Apple trackpad.
- [ ] Magic Mouse / Magic Trackpad where available.
- [ ] Generic USB three-button mouse.
- [ ] Generic five-button mouse.
- [ ] Bluetooth mouse.
- [ ] Supported Logitech devices over Bluetooth, Bolt/Unifying receiver, and direct USB as applicable.
- [ ] Two identical devices attached simultaneously.
- [ ] Hot-plug, receiver removal, sleep/wake, and low-battery transitions.

### Applications and environments

- [ ] AppKit, SwiftUI, Safari, Chromium, Electron, and games.
- [ ] Terminal, secure-input/password fields, and screen lock.
- [ ] Remote desktop, screen sharing, and virtual machines.
- [ ] Wine/non-bundled process identity.
- [ ] Full-screen apps, Mission Control, Spaces, and multiple displays.
- [ ] Concurrent LinearMouse/SteerMouse/BetterMouse/Logi Options+/Karabiner scenarios.

### Failure injection

- [ ] Accessibility revoked while idle and during every stateful interaction.
- [ ] Event tap disabled by timeout and user input.
- [ ] Device disappears between down and up.
- [ ] App/display/profile changes between down and up.
- [ ] Settings document truncated, unknown-versioned, and partially invalid.
- [ ] Forced kill during a system or hardware mutation.
- [ ] Synthetic event marker missing or malformed.
- [ ] Event thread restart while smoothing, auto-scroll, or a held action is active.
- [ ] With Settings closed and the transient Dock icon hidden, status-item and relaunch recovery remain possible. If menu-bar hiding is ever added, verify an all-hidden recovery path before release.

## Definition of done

The integration is done when:

- [ ] Every capability in the scope table is shipped or explicitly documented as unsupported/deferred with evidence.
- [x] One Jostle process and one status item control windowing, Keep Awake, and input customization.
- [x] Existing settings decode backward-compatibly, and the supported LinearMouse subset migrates once without overwriting existing profiles.
- [x] Input customization is opt-in and independently disableable.
- [ ] The callback is bounded, fail-open, and free of main-thread or disk dependencies.
- [ ] Stateful input always drains or releases safely. **Partial:** all currently implemented stateful interactions have cancellation and release coverage; future mappings must satisfy the same contract.
- [ ] System/hardware changes restore without overwriting newer external changes.
- [x] Keep Awake works when Accessibility or the event tap is unavailable.
- [ ] The full automated suite and required manual matrix pass. The 57-test core suite and 67-test app suite pass; signed-app runtime evidence is within the ADR thresholds, but the documented external/manual matrix is not complete.
- [x] Recovery, privacy, supported devices and exclusions, conflicts, licensing, and troubleshooting are documented.
