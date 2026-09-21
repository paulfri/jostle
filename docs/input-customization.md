# Input customization support, privacy, and recovery

Jostle's input customization is optional and independent of window controls and Keep Awake. Unsupported or unattributed input passes through unchanged. This page documents the implemented support boundary rather than promising compatibility with every device or input utility.

## Supported behavior

Jostle currently supports:

- mice and pointer-class IOHID devices whose primary usage identifies them as a mouse or pointer;
- trackpads that report genuine touchpad conformance;
- USB, Bluetooth, and receiver-connected pointing devices exposed through IOHID;
- per-axis scrolling direction, distance, speed, acceleration, smoothing, inertia, and bounce;
- ordered scroll profiles matched by mouse/trackpad category, exact device, application bundle identifier, or process name;
- Button 4 and Button 5 navigation, window, display, and Keep Awake actions;
- per-device Focus Follows Pointer gating; and
- read-only battery levels from the public Bluetooth Battery Service (`180F`) and Battery Level characteristic (`2A19`).

Exact-device attribution is best effort because macOS does not attach a usable IOHID sender identifier to every Core Graphics event. Jostle uses a bounded recent-device fallback when direct attribution is unavailable. Keyboard-primary composite devices are excluded even if they advertise secondary pointer collections.

Jostle does **not** currently support:

- pointer speed or pointer acceleration changes;
- hardware DPI changes;
- Logitech HID++, Logitech high-resolution wheel mode, or another vendor protocol;
- vendor-specific battery protocols;
- arbitrary mouse buttons beyond Button 4 and Button 5; or
- exclusive device seizure.

A missing battery percentage does not mean the device is disconnected. Many pointing devices expose battery state only through a vendor protocol that Jostle intentionally does not implement.

## Compatibility with other input utilities

Only one utility should normally transform a given scrolling or button behavior. While Settings is open, Jostle shows a non-blocking warning when it detects a known overlapping utility such as LinearMouse, SteerMouse, BetterMouse, Mac Mouse Fix, USB Overdrive, Scroll Reverser, Mos, Logi Options+, or Karabiner-Elements.

Detection is advisory and based on running application identity. It cannot detect every background component and does not terminate or reconfigure another app. If scrolling is doubled, reversed inconsistently, delayed, or missing, disable overlapping transformations in one utility before changing Jostle profiles.

## Privacy

Input transformation occurs locally. Jostle does not include telemetry or cloud sync and does not record keystrokes, pointer coordinates, window titles, browsing history, or event streams.

Jostle stores its typed settings in the current user's preferences. Exact-device rules can contain a stable, privacy-preserving device key and a display name. Application profiles can contain bundle identifiers or process names. The one-time LinearMouse migration reads `~/.config/linearmouse/linearmouse.json` locally and never modifies that file.

Bluetooth scanning starts only when the selected battery display mode needs battery information. Jostle filters standard Battery Service discoveries against its pointing-device inventory and does not write device firmware settings.

### Diagnostics reports

Choose **Settings → General → Diagnostics…** to preview a report before copying or saving it. Reports include:

- Jostle and macOS versions;
- permission, Safe Mode, session, and event-tap state;
- aggregate event-tap and smoothing timing histograms;
- tap-disable recovery counts;
- counts of profiles, rules, connected device categories, and application overrides; and
- canonical names of detected input-utility conflicts.

Reports deliberately omit keys, pointer coordinates, event timestamps, application names and identifiers, profile names, device names and identifiers, serial numbers, and file-system paths. Runtime timing histograms are in-memory and reset when Jostle exits.

Input-settings backup files are **not** diagnostics reports. A backup contains the full input configuration needed to restore exact-device and application/process profiles. Review it before sharing.

## Backup, import, and reset

At the bottom of **Settings → Input**:

- **Export Input Settings…** writes a versioned JSON backup containing only input customization.
- **Import Input Settings…** validates and replaces only input customization.
- **Reset Input Settings…** restores only input customization defaults.

These operations do not change window gestures, Keep Awake, login, update, or per-application window/focus settings. Jostle rejects the wrong document type, unsupported future versions, future input schemas, empty profile identifiers, and duplicate profile identifiers without changing current settings.

## Troubleshooting

### Input customization does not activate

1. Confirm **Enable input customizations** is selected in Settings → Input.
2. Grant Jostle Accessibility permission in System Settings → Privacy & Security → Accessibility.
3. Check whether Settings says Jostle is in Safe Mode.
4. Resolve any concurrent-input-utility warning.
5. Use the status menu's retry action if the event tap is unavailable.
6. Open **Diagnostics…** and confirm `requested`, `operational`, and `input_customizations_active` are `yes`.

Window controls and Keep Awake remain available independently when input customization is off. Keep Awake does not require Accessibility permission.

### The wrong device profile applies

Disconnect and reconnect the intended pointing device, then verify its entry under **Device Overrides**. Sender attribution is best effort; receiver-connected devices that share an indistinguishable event source may not support reliable exact-device profiles. Prefer a mouse/trackpad category profile when exact attribution is unstable.

### Scrolling repeats, sticks, or feels delayed

Disable overlapping scroll transformation in other utilities, then temporarily disable smoothing in the effective Jostle profile. Cancel an active interaction with `Escape`. If the issue remains, preview a diagnostics report and check callback/timer p99 and event-tap timeout counts.

### Battery state is unavailable

Confirm battery presentation is enabled in General settings and Bluetooth access is granted. The device must be in Jostle's pointing-device inventory, connected through Bluetooth, and expose the public Battery Service. Receiver-only and vendor-protocol battery readings are unsupported.

## Recovery

Safe Mode disables input interception for one launch without erasing configuration. Use any of these paths:

- hold **Shift-Option** while opening Jostle;
- allow automatic Safe Mode after three consecutive unclean launches; or
- launch with `--safe-mode`.

For an app installed in `/Applications`:

```sh
osascript -e 'tell application id "fm.pau.jostle" to quit' 2>/dev/null || pkill -x Jostle
open -na "/Applications/Jostle.app" --args --safe-mode --show-settings
```

To persistently turn input customization off while preserving its configuration, use `--disable-input-customizations` instead. To erase only input customization, use `--reset-input-customizations`.

For the repository's signed development app:

```sh
osascript -e 'tell application id "fm.pau.jostle.development" to quit' 2>/dev/null || pkill -x "Jostle Development"
open -na "$HOME/Applications/Jostle Development.app" --args --safe-mode --show-settings
```

After recovery, close Settings and launch Jostle normally. If Accessibility was revoked, re-enable it before turning input customization back on.
