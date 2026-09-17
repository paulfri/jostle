import AppKit

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settingsStore: SettingsStore
    private let eventTapController: EventTapController
    private let loginItemController: LoginItemController
    private let currentApplicationProvider: () -> RunningApplicationInfo?
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var recentApplication: RunningApplicationInfo?
    private var overallDisabled = false
    private var accessibilityAvailable = true

    var renderedMenu: NSMenu { menu }

    init(
        settingsStore: SettingsStore,
        eventTapController: EventTapController,
        loginItemController: LoginItemController,
        currentApplicationProvider: @escaping () -> RunningApplicationInfo? = {
            guard let application = NSWorkspace.shared.frontmostApplication,
                  application.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return nil
            }
            return RunningApplicationInfo(application: application)
        },
        onOpenSettings: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.eventTapController = eventTapController
        self.loginItemController = loginItemController
        self.currentApplicationProvider = currentApplicationProvider
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        let image = NSImage(named: "MenuIcon")
            ?? NSImage(systemSymbolName: "rectangle.on.rectangle.angled", accessibilityDescription: "Jostle")
        image?.isTemplate = true
        statusItem.button?.image = image
        settingsStore.onChange = { [weak self] in self?.refresh() }
        loginItemController.onChange = { [weak self] in self?.refresh() }
        updateCurrentApplication()
        refresh()
    }

    deinit {
        settingsStore.onChange = nil
        loginItemController.onChange = nil
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

    func menuWillOpen(_ menu: NSMenu) {
        updateCurrentApplication()
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

        let startAtLoginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleStartAtLogin(_:)),
            keyEquivalent: ""
        )
        startAtLoginItem.target = self
        startAtLoginItem.state = loginItemController.isEnabled ? .on : .off
        menu.addItem(startAtLoginItem)
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
        guard let recentApplication else { return false }
        return settingsStore.settings.excludedApplications[recentApplication.key] == nil
    }

    private func updateCurrentApplication() {
        guard let application = currentApplicationProvider() else { return }
        recentApplication = application
    }

    @objc private func toggleOverallDisabled(_ sender: NSMenuItem) {
        overallDisabled.toggle()
        eventTapController.setEnabled(!overallDisabled)
        refresh()
    }

    @objc private func toggleStartAtLogin(_ sender: NSMenuItem) {
        loginItemController.setEnabled(!loginItemController.isEnabled)
        guard let errorMessage = loginItemController.errorMessage else { return }

        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t Update Start at Login"
        alert.informativeText = errorMessage
        alert.runModal()
        loginItemController.clearError()
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
        onOpenSettings()
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
