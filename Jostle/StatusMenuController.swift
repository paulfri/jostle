import AppKit

final class StatusMenuController: NSObject {
    private let settingsStore: SettingsStore
    private let eventTapController: EventTapController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var recentApplication: RunningApplicationInfo?
    private var overallDisabled = false
    private var accessibilityAvailable = true

    var renderedMenu: NSMenu { menu }

    init(settingsStore: SettingsStore, eventTapController: EventTapController) {
        self.settingsStore = settingsStore
        self.eventTapController = eventTapController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.autoenablesItems = false
        statusItem.menu = menu
        let image = NSImage(named: "MenuIcon")
            ?? NSImage(systemSymbolName: "rectangle.on.rectangle.angled", accessibilityDescription: "Jostle")
        image?.isTemplate = true
        statusItem.button?.image = image
        settingsStore.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    deinit {
        settingsStore.onChange = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func setRecentApplication(_ application: RunningApplicationInfo) {
        recentApplication = application
        refresh()
    }

    func setAccessibilityAvailable(_ available: Bool) {
        accessibilityAvailable = available
        refresh()
    }

    func refresh() {
        menu.removeAllItems()

        if !accessibilityAvailable {
            let permissionItem = NSMenuItem(
                title: "Accessibility Access Required",
                action: #selector(openAccessibilitySettings(_:)),
                keyEquivalent: ""
            )
            permissionItem.target = self
            menu.addItem(permissionItem)
            menu.addItem(.separator())
        }

        let enabledItem = NSMenuItem(
            title: "Jostle Enabled",
            action: #selector(toggleOverallDisabled(_:)),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = accessibilityAvailable && !overallDisabled ? .on : .off
        enabledItem.isEnabled = accessibilityAvailable
        menu.addItem(enabledItem)
        menu.addItem(.separator())

        let excludeItem = NSMenuItem(
            title: recentApplication.map { "Exclude \($0.name)" } ?? "Exclude Current App",
            action: #selector(excludeRecentApplication(_:)),
            keyEquivalent: ""
        )
        excludeItem.target = self
        excludeItem.isEnabled = canExcludeRecentApplication
        menu.addItem(excludeItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Jostle",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)
    }

    private var canExcludeRecentApplication: Bool {
        guard accessibilityAvailable, let recentApplication else { return false }
        return settingsStore.settings.excludedApplications[recentApplication.key] == nil
    }

    @objc private func toggleOverallDisabled(_ sender: NSMenuItem) {
        overallDisabled.toggle()
        eventTapController.setEnabled(!overallDisabled)
        refresh()
    }

    @objc private func excludeRecentApplication(_ sender: NSMenuItem) {
        guard canExcludeRecentApplication, let recentApplication else { return }
        settingsStore.update { settings in
            settings.setApplicationExcluded(
                key: recentApplication.key,
                displayName: recentApplication.name,
                excluded: true
            )
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.sendAction(
            Selector(("showSettingsWindow:")),
            to: nil,
            from: self
        )
    }

    @objc private func openAccessibilitySettings(_ sender: NSMenuItem) {
        guard let URL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(URL)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
