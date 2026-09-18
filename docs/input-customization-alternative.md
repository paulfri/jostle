Yes—but I’d combine them around a stronger product idea rather than simply importing every LinearMouse checkbox:

> **Jostle becomes the interaction layer between your pointing device and macOS.**

That makes window control, focus-follows-pointer, pointer tuning, scrolling, button mappings, and even Keep Awake feel like one coherent utility.

## The compelling integrations

The real opportunity is where Jostle and LinearMouse overlap:

- **Thumb button + drag anywhere** → move window
- **Another button + drag** → resize window
- **Thumb button + wheel** → cycle half, third, two-thirds, maximize
- **Button swipe/chord** → throw window to another display
- **Long-press button** → toggle Keep Awake
- **Per-device focus behavior** → focus follows pointer for a mouse, but not a trackpad
- **Per-app behavior** → browser buttons remain Back/Forward, while CAD apps use them for window or tool actions
- **Short press remains Back; long press performs a Jostle action**

That is meaningfully better than running two unrelated utilities.

## What to adopt

### First-class features

1. **Per-device profiles**
   - Mouse versus trackpad
   - Individual devices by vendor/product ID
   - Optional per-application overrides

2. **Pointer**
   - Speed
   - Acceleration, including fully linear movement
   - Focus-follows-pointer behavior

3. **Scrolling**
   - Independent natural-scrolling direction per device
   - Speed and acceleration
   - Horizontal/vertical controls
   - Modifier-based behavior

4. **Buttons**
   - Basic remapping
   - Short press, long press, and button chords
   - Jostle window actions as native outcomes
   - Universal Back/Forward

5. **Small reliability features**
   - Click debouncing
   - Middle-button autoscroll

### Leave until later

- Sophisticated smoothed scrolling and inertia
- Shell-command execution
- Huge generic action catalogues
- Logitech HID++ battery, DPI, and receiver support
- Extensive device-specific workarounds

Those are valuable, but they would turn the project into a hardware compatibility programme rather than a window utility.

## Best initial scope

I’d start with a deliberately smaller “Jostle Mouse” feature set:

1. Reverse scrolling independently for mouse and trackpad
2. Pointer speed and acceleration
3. Recognise extra mouse buttons
4. Allow buttons to activate move/resize gestures
5. Map buttons to Jostle window and Keep Awake actions
6. Add focus-follows-pointer with per-device and per-app rules

That is enough to establish the combined proposition without attempting immediate LinearMouse parity.

## Architectural impact

This would be a substantial expansion, not just another settings pane:

- Jostle’s event tap currently handles buttons, drags, and keyboard events; it would need pointer movement and scroll events.
- Device-specific behavior requires HID device discovery and reliable event-to-device association.
- The flat `JostleSettings` model would probably need to become layered profiles:

```text
Global defaults
  └── Device profile
        └── Application override
              └── Temporary modifier override
```

- Event handling should become an ordered transformation pipeline:
  1. Identify device and context
  2. Resolve effective profile
  3. Recognise chords/holds/gestures
  4. Run Jostle window actions
  5. Transform or pass through the original event
- Synthetic-event recursion and conflicts with LinearMouse, BetterMouse, Mac Mouse Fix, etc. would need careful handling.

LinearMouse itself already has much of this infrastructure. It is [MIT licensed](https://github.com/linearmouse/linearmouse/blob/main/LICENSE), so selective reuse is possible with attribution, although integrating its architecture cleanly may still be harder than reimplementing a focused subset.

## Product recommendation

Don’t position it as “Jostle now also clones LinearMouse.” Position it as:

> **Make every mouse work the way you expect—and use it to control any window under the pointer.**

LinearMouse parity alone offers little differentiation. **Device-aware window gestures** are the distinctive part and should drive the roadmap. Focus follows pointer is an excellent bridge feature because it forces Jostle to understand continuous pointer movement, app context, and eventually device-specific profiles.

Sources: [LinearMouse configuration documentation](https://github.com/linearmouse/linearmouse/blob/main/Documentation/Configuration.md), [LinearMouse project](https://github.com/linearmouse/linearmouse).
