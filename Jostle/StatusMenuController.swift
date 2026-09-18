import AppKit
import JostleCore

private final class StatusCenterImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settingsStore: SettingsStore
    private let eventTapController: EventTapController
    private let keepAwakeController: KeepAwakeController
    private let loginItemController: LoginItemController
    private let updateController: UpdateControlling?
    private let currentApplicationProvider: () -> RunningApplicationInfo?
    private let applicationName: String
    private let onRuntimeRefresh: () -> Void
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem
    private let baseImage: NSImage
    private let centerStateImageView = StatusCenterImageView()
    private let menu = NSMenu()
    private weak var keepAwakeToggleItem: NSMenuItem?
    private var countdownRefreshTimer: Timer?
    private var recentApplication: RunningApplicationInfo?
    private var runtimeAvailability = RuntimeAvailability.ready

    var renderedMenu: NSMenu { menu }

    init(
        settingsStore: SettingsStore,
        eventTapController: EventTapController,
        keepAwakeController: KeepAwakeController,
        loginItemController: LoginItemController,
        updateController: UpdateControlling? = nil,
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
        self.keepAwakeController = keepAwakeController
        self.loginItemController = loginItemController
        self.updateController = updateController
        self.currentApplicationProvider = currentApplicationProvider
        self.applicationName = applicationName
        self.onRuntimeRefresh = onRuntimeRefresh
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        baseImage = NSImage(named: "MenuIcon")
            ?? NSImage(
                systemSymbolName: "viewfinder",
                accessibilityDescription: applicationName
            )
            ?? NSImage(size: NSSize(width: 16, height: 16))
        super.init()

        menu.autoenablesItems = false
        menu.delegate = self
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            centerStateImageView.imageScaling = .scaleProportionallyDown
            centerStateImageView.translatesAutoresizingMaskIntoConstraints = false
            centerStateImageView.setAccessibilityElement(false)
            button.addSubview(centerStateImageView)
            NSLayoutConstraint.activate([
                centerStateImageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                centerStateImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                centerStateImageView.widthAnchor.constraint(equalToConstant: 8),
                centerStateImageView.heightAnchor.constraint(equalToConstant: 8),
            ])
        }
        settingsStore.onChange = { [weak self] in self?.refresh() }
        keepAwakeController.onChange = { [weak self] in self?.refresh() }
        loginItemController.onChange = { [weak self] in self?.refresh() }
        updateCurrentApplication()
        refresh()
    }

    deinit {
        countdownRefreshTimer?.invalidate()
        settingsStore.onChange = nil
        keepAwakeController.onChange = nil
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

    func handleStatusItemClick(type: NSEvent.EventType) {
        let activatesOnLeftClick = settingsStore.settings.keepAwakeActivateOnLeftClick
        let shouldToggle = activatesOnLeftClick
            ? type == .leftMouseUp
            : type == .rightMouseUp
        if shouldToggle {
            keepAwakeController.toggle()
        } else {
            showMenu()
        }
    }

    func refresh() {
        renderStatusIcon()
        menu.removeAllItems()

        addRuntimeStatusIfNeeded()
        addWindowGestureItems()
        menu.addItem(.separator())
        addKeepAwakeItems()
        menu.addItem(.separator())
        addApplicationItems()
        addUpdateItemIfAvailable()
        addSettingsAndQuitItems()
        updateCountdownRefreshTimer()
    }

    private func addRuntimeStatusIfNeeded() {
        switch runtimeAvailability {
        case .ready:
            break
        case .accessibilityRequired:
            let item = NSMenuItem(
                title: "Accessibility Access Required…",
                action: #selector(openAccessibilitySettings(_:)),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
            menu.addItem(.separator())
        case .eventTapUnavailable:
            let item = NSMenuItem(
                title: "Event Monitor Unavailable — Retry",
                action: #selector(retryEventMonitor(_:)),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
            menu.addItem(.separator())
        }
    }

    private func addWindowGestureItems() {
        let enabledItem = NSMenuItem(
            title: "Window Gestures Enabled",
            action: #selector(toggleOverallDisabled(_:)),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = runtimeAvailability == .ready
            && eventTapController.requestedEnabled ? .on : .off
        enabledItem.isEnabled = runtimeAvailability == .ready
        menu.addItem(enabledItem)
    }

    private func addKeepAwakeItems() {
        if let errorMessage = keepAwakeController.lastErrorMessage {
            let errorItem = NSMenuItem(title: "Keep Awake Error: \(errorMessage)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        let toggleItem = NSMenuItem(
            title: keepAwakeToggleTitle,
            action: #selector(toggleKeepAwake(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = keepAwakeController.isEnabled ? .on : .off
        menu.addItem(toggleItem)
        keepAwakeToggleItem = toggleItem

        let durationItem = NSMenuItem(title: "Keep Awake For", action: nil, keyEquivalent: "")
        let durationMenu = NSMenu(title: "Keep Awake For")
        for preset in KeepAwakeDurationPreset.allCases {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(startKeepAwakeDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.rawValue
            item.state = activeDurationMatches(preset) ? .on : .off
            durationMenu.addItem(item)
        }
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        let allowDisplaySleepItem = NSMenuItem(
            title: "Allow Display to Sleep",
            action: #selector(toggleAllowDisplaySleep(_:)),
            keyEquivalent: ""
        )
        allowDisplaySleepItem.target = self
        allowDisplaySleepItem.state = settingsStore.settings.keepAwakeAllowDisplaySleep ? .on : .off
        menu.addItem(allowDisplaySleepItem)
    }

    private func addApplicationItems() {
        let startAtLoginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleStartAtLogin(_:)),
            keyEquivalent: ""
        )
        startAtLoginItem.target = self
        startAtLoginItem.state = loginItemController.isEnabled ? .on : .off
        menu.addItem(startAtLoginItem)

        let excludeItem = NSMenuItem(
            title: recentApplication.map { "Exclude \($0.name)" } ?? "Exclude Current App",
            action: #selector(excludeRecentApplication(_:)),
            keyEquivalent: ""
        )
        excludeItem.target = self
        excludeItem.isEnabled = recentApplication != nil
        excludeItem.state = isRecentApplicationExcluded ? .on : .off
        menu.addItem(excludeItem)
    }

    private func addUpdateItemIfAvailable() {
        guard let updateController else { return }
        menu.addItem(.separator())
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = updateController.canCheckForUpdates
        menu.addItem(updateItem)
    }

    private func addSettingsAndQuitItems() {
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

    private var keepAwakeToggleTitle: String {
        guard keepAwakeController.isEnabled else { return "Keep Mac Awake" }
        if case .paused = keepAwakeController.state {
            return "Keep Mac Awake — Paused While Locked"
        }
        guard let remaining = keepAwakeController.remainingTime else {
            return "Keep Mac Awake — Indefinitely"
        }
        return "Keep Mac Awake — \(Self.formatRemaining(remaining)) Remaining"
    }

    private func activeDurationMatches(_ preset: KeepAwakeDurationPreset) -> Bool {
        guard keepAwakeController.isEnabled,
              let duration = keepAwakeController.duration else {
            return false
        }
        return duration == preset.duration
    }

    private var isRecentApplicationExcluded: Bool {
        guard let recentApplication else { return false }
        return settingsStore.settings.excludedApplications[recentApplication.key] != nil
    }

    private func updateCurrentApplication() {
        guard let application = currentApplicationProvider() else { return }
        recentApplication = application
    }

    private func renderStatusIcon() {
        let windowAvailable = runtimeAvailability == .ready
            && eventTapController.requestedEnabled
        let presentation = StatusIconRenderer.presentation(
            baseImage: baseImage,
            applicationName: applicationName,
            windowGesturesAvailable: windowAvailable,
            centerState: statusCenterState,
            dimWhenInactive: settingsStore.settings.keepAwakeDimWhenInactive,
            indicatorStyle: settingsStore.settings.keepAwakeIndicatorStyle
        )

        if let button = statusItem.button {
            button.appearsDisabled = presentation.shouldDim
            button.contentTintColor = presentation.iconTintColor
            button.image = presentation.image
        }

        if let symbolName = presentation.overlaySymbolName,
           let symbol = NSImage(
               systemSymbolName: symbolName,
               accessibilityDescription: nil
           )?.withSymbolConfiguration(
               NSImage.SymbolConfiguration(pointSize: 7.5, weight: .semibold)
           ) {
            symbol.isTemplate = true
            centerStateImageView.image = symbol
            centerStateImageView.contentTintColor = presentation.overlayTintColor
            centerStateImageView.isHidden = false
        } else {
            centerStateImageView.image = nil
            centerStateImageView.isHidden = true
        }
    }

    private var statusCenterState: StatusIconRenderer.CenterState {
        if case .paused = keepAwakeController.state {
            return .paused
        }
        if keepAwakeController.isEnabled {
            return .awake
        }
        if keepAwakeController.lastErrorMessage != nil {
            return .attention
        }
        return .none
    }

    private func showMenu() {
        onRuntimeRefresh()
        updateCurrentApplication()
        refresh()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func updateCountdownRefreshTimer() {
        let needsRefresh = keepAwakeController.isEnabled
            && keepAwakeController.remainingTime != nil
        if needsRefresh, countdownRefreshTimer == nil {
            let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
                guard let self else { return }
                keepAwakeToggleItem?.title = keepAwakeToggleTitle
            }
            RunLoop.main.add(timer, forMode: .common)
            countdownRefreshTimer = timer
        } else if !needsRefresh {
            countdownRefreshTimer?.invalidate()
            countdownRefreshTimer = nil
        }
    }

    private static func formatRemaining(_ interval: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(interval / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        handleStatusItemClick(type: NSApp.currentEvent?.type ?? .leftMouseUp)
    }

    @objc private func toggleOverallDisabled(_ sender: NSMenuItem) {
        eventTapController.setEnabled(!eventTapController.requestedEnabled)
        onRuntimeRefresh()
        refresh()
    }

    @objc private func toggleKeepAwake(_ sender: NSMenuItem) {
        keepAwakeController.toggle()
    }

    @objc private func startKeepAwakeDuration(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preset = KeepAwakeDurationPreset(rawValue: rawValue) else {
            return
        }
        keepAwakeController.start(preset.duration)
    }

    @objc private func toggleAllowDisplaySleep(_ sender: NSMenuItem) {
        settingsStore.update { settings in
            settings.keepAwakeAllowDisplaySleep.toggle()
        }
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

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        updateController?.checkForUpdates()
    }

    @objc private func retryEventMonitor(_ sender: NSMenuItem) {
        onRuntimeRefresh()
    }

    @objc private func openAccessibilitySettings(_ sender: NSMenuItem) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
