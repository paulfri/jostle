import Carbon
import Combine
import Foundation
import JostleCore

private func jostleGlobalShortcutHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let controller = Unmanaged<GlobalShortcutController>.fromOpaque(userData)
        .takeUnretainedValue()
    controller.handleShortcut()
    return noErr
}

final class GlobalShortcutController: ObservableObject {
    @Published private(set) var errorMessage: String?
    var onTrigger: (() -> Void)?

    private let settingsStore: SettingsStore
    private var settingsCancellable: AnyCancellable?
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            jostleGlobalShortcutHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        register(settingsStore.settings.keepAwakeShortcut)
        settingsCancellable = settingsStore.$settings
            .map(\.keepAwakeShortcut)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] shortcut in
                self?.register(shortcut)
            }
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    fileprivate func handleShortcut() {
        onTrigger?()
    }

    private func register(_ shortcut: GlobalShortcut?) {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        errorMessage = nil
        guard let shortcut else { return }
        guard shortcut.isValid,
              shortcut.modifiers.isSubset(of: [.control, .option, .shift, .command]) else {
            errorMessage = "Choose a shortcut with Command, Control, Option, or Shift."
            return
        }

        let identifier = EventHotKeyID(signature: OSType(0x4A4F5354), id: 1) // JOST
        var registeredHotKey: EventHotKeyRef?
        let result = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(shortcut.modifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &registeredHotKey
        )
        guard result == noErr, let registeredHotKey else {
            errorMessage = "That keyboard shortcut is already in use."
            return
        }
        hotKey = registeredHotKey
    }

    private func carbonModifiers(_ modifiers: Set<Modifier>) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }
}
