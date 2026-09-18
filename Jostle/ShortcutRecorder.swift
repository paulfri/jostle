import AppKit
import JostleCore
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: GlobalShortcut?

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onChange = { context.coordinator.shortcut.wrappedValue = $0 }
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ view: ShortcutRecorderButton, context: Context) {
        view.shortcut = shortcut
    }

    final class Coordinator {
        let shortcut: Binding<GlobalShortcut?>

        init(shortcut: Binding<GlobalShortcut?>) {
            self.shortcut = shortcut
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut: GlobalShortcut? {
        didSet { updateTitle() }
    }
    var onChange: ((GlobalShortcut?) -> Void)?

    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        setAccessibilityLabel("Toggle Keep Awake shortcut")
        toolTip = "Click, then type a shortcut. Press Delete to clear it."
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 26)
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            isRecording = false
            updateTitle()
        }
        return result
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            window?.makeFirstResponder(nil)
        case 51, 117: // Delete / forward delete
            shortcut = nil
            onChange?(nil)
            window?.makeFirstResponder(nil)
        default:
            let modifiers = Self.modifiers(from: event.modifierFlags)
            guard !modifiers.isEmpty else {
                NSSound.beep()
                return
            }
            let shortcut = GlobalShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            self.shortcut = shortcut
            onChange?(shortcut)
            window?.makeFirstResponder(nil)
        }
    }

    @objc private func beginRecording() {
        isRecording = true
        updateTitle()
        window?.makeFirstResponder(self)
    }

    private func updateTitle() {
        if isRecording {
            title = "Type Shortcut…"
        } else if let shortcut {
            title = ShortcutFormatter.string(for: shortcut)
        } else {
            title = "Record Shortcut"
        }
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<Modifier> {
        var result: Set<Modifier> = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }
}

enum ShortcutFormatter {
    static func string(for shortcut: GlobalShortcut) -> String {
        var value = ""
        if shortcut.modifiers.contains(.control) { value += "⌃" }
        if shortcut.modifiers.contains(.option) { value += "⌥" }
        if shortcut.modifiers.contains(.shift) { value += "⇧" }
        if shortcut.modifiers.contains(.command) { value += "⌘" }
        value += keyNames[shortcut.keyCode] ?? "Key \(shortcut.keyCode)"
        return value
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "−", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋", 65: ".", 67: "*", 69: "+", 71: "Clear",
        75: "/", 76: "↩", 78: "−", 81: "=", 82: "0", 83: "1", 84: "2",
        85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4",
        119: "↘", 120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→",
        125: "↓", 126: "↑"
    ]
}
