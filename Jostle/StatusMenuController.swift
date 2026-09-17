import AppKit

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settingsStore: SettingsStore
    private let eventTapController: EventTapController
    private let loginItemController: LoginItemController
    private let currentApplicationProvider: () -> RunningApplicationInfo?
    private let applicationName: String
    private let onRuntimeRefresh: () -> Void
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var recentApplication: RunningApplicationInfo?
    private var runtimeAvailability = RuntimeAvailability.ready

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
        applicationName: String = AppBrand.applicationName,
        onRuntimeRefresh: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.eventTapController = eventTapController
        self.loginItemController = loginItemController
        self.currentApplicationProvider = currentApplicationProvider
        self.applicationName = applicationName
        self.onRuntimeRefresh = onRuntimeRefresh
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        let image = NSImage(named: "MenuIcon")
            ?? NSImage(
                systemSymbolName: "rectangle.on.rectangle.angled",
                accessibilityDescription: applicationName
            )
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

    func setRuntimeAvailability(_ availability: RuntimeAvailability) {
        guard runtimeAvailability != availability else { return }
        runtimeAvailability = availability
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) {
        onRuntimeRefresh()
        updateCurrentApplication()
        refresh()
    }

    func refresh() {
        menu.removeAllItems()
        statusItem.button?.appearsDisabled = runtimeAvailability != .ready
            || !eventTapController.requestedEnabled

        switch runtimeAvailability {
        case .ready:
            break
        case .accessibilityRequired:
            let permissionItem = NSMenuItem(
                title: "Accessibility Access Required…",
                action: #selector(openAccessibilitySettings(_:)),
                keyEquivalent: ""
            )
            permissionItem.target = self
            menu.addItem(permissionItem)
            menu.addItem(.separator())
        case .eventTapUnavailable:
            let retryItem = NSMenuItem(
                title: "Event Monitor Unavailable — Retry",
                action: #selector(retryEventMonitor(_:)),
                keyEquivalent: ""
            )
            retryItem.target = self
            menu.addItem(retryItem)
            menu.addItem(.separator())
        }

        let enabledItem = NSMenuItem(
            title: "\(applicationName) Enabled",
            action: #selector(toggleOverallDisabled(_:)),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = runtimeAvailability == .ready
            && eventTapController.requestedEnabled ? .on : .off
        enabledItem.isEnabled = runtimeAvailability == .ready
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
        excludeItem.isEnabled = recentApplication != nil
        excludeItem.state = isRecentApplicationExcluded ? .on : .off
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
            title: "Quit \(applicationName)",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)
    }

    private var isRecentApplicationExcluded: Bool {
        guard let recentApplication else { return false }
        return settingsStore.settings.excludedApplications[recentApplication.key] != nil
    }

    private func updateCurrentApplication() {
        guard let application = currentApplicationProvider() else { return }
        recentApplication = application
    }

    @objc private func toggleOverallDisabled(_ sender: NSMenuItem) {
        eventTapController.setEnabled(!eventTapController.requestedEnabled)
        onRuntimeRefresh()
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
        guard let recentApplication else { return }
        let shouldExclude = !isRecentApplicationExcluded
        settingsStore.update { settings in
            settings.setApplicationExcluded(
                key: recentApplication.key,
                displayName: shouldExclude ? recentApplication.name : nil,
                excluded: shouldExclude
            )
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        onOpenSettings()
    }

    @objc private func retryEventMonitor(_ sender: NSMenuItem) {
        onRuntimeRefresh()
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
