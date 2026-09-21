import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let loginItemController: LoginItemController
    private let inputUtilityConflictMonitor: InputUtilityConflictMonitor
    private var activationPolicyBeforePresenting: NSApplication.ActivationPolicy?
    private var mainMenuBeforePresenting: NSMenu?
    private var commandQMonitor: Any?
    private lazy var settingsMainMenu = Self.makeSettingsMainMenu(target: self)

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        globalShortcutController: GlobalShortcutController,
        pointingDeviceManager: PointingDeviceManager,
        safeMode: Bool = false,
        updateController: SparkleUpdateController? = nil,
        diagnosticsReportProvider: @escaping () -> String
    ) {
        self.loginItemController = loginItemController
        let inputUtilityConflictMonitor = InputUtilityConflictMonitor()
        self.inputUtilityConflictMonitor = inputUtilityConflictMonitor
        let tabController = NSTabViewController()
        tabController.tabStyle = .toolbar
        tabController.transitionOptions = []

        let generalController = NSHostingController(
            rootView: GeneralSettingsPane(
                settingsStore: settingsStore,
                loginItemController: loginItemController,
                diagnosticsReportProvider: diagnosticsReportProvider
            )
            .tint(Color(nsColor: AppBrand.accentColor))
        )
        let generalItem = NSTabViewItem(viewController: generalController)
        generalItem.label = "General"
        generalItem.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "General Settings"
        )
        tabController.addTabViewItem(generalItem)

        let gesturesController = NSHostingController(
            rootView: GesturesSettingsPane(settingsStore: settingsStore)
                .tint(Color(nsColor: AppBrand.accentColor))
        )
        let gesturesItem = NSTabViewItem(viewController: gesturesController)
        gesturesItem.label = "Gestures"
        let gesturesImage = (NSImage(named: "MenuIcon")?.copy() as? NSImage)
            ?? NSImage(
                systemSymbolName: "viewfinder",
                accessibilityDescription: "Jostle Gestures"
            )
        gesturesImage?.isTemplate = true
        gesturesImage?.accessibilityDescription = "Jostle Gestures"
        gesturesItem.image = gesturesImage
        tabController.addTabViewItem(gesturesItem)

        let inputController = NSHostingController(
            rootView: InputSettingsPane(
                settingsStore: settingsStore,
                pointingDeviceManager: pointingDeviceManager,
                conflictMonitor: inputUtilityConflictMonitor,
                safeMode: safeMode
            )
            .tint(Color(nsColor: AppBrand.accentColor))
        )
        let inputItem = NSTabViewItem(viewController: inputController)
        inputItem.label = "Input"
        inputItem.image = NSImage(
            systemSymbolName: "computermouse",
            accessibilityDescription: "Input Customization"
        )
        tabController.addTabViewItem(inputItem)

        let keepAwakeController = NSHostingController(
            rootView: KeepAwakeSettingsPane(
                settingsStore: settingsStore,
                globalShortcutController: globalShortcutController
            )
            .tint(Color(nsColor: AppBrand.accentColor))
        )
        let keepAwakeItem = NSTabViewItem(viewController: keepAwakeController)
        keepAwakeItem.label = "Keep Awake"
        keepAwakeItem.image = NSImage(
            systemSymbolName: "bolt.fill",
            accessibilityDescription: "Keep Awake"
        )
        tabController.addTabViewItem(keepAwakeItem)

        let snappingController = NSHostingController(
            rootView: SnappingSettingsPane(settingsStore: settingsStore)
                .tint(Color(nsColor: AppBrand.accentColor))
        )
        let snappingItem = NSTabViewItem(viewController: snappingController)
        snappingItem.label = "Snapping"
        snappingItem.image = NSImage(
            systemSymbolName: "rectangle.split.2x1",
            accessibilityDescription: "Snapping"
        )
        tabController.addTabViewItem(snappingItem)

        let applicationsController = NSHostingController(
            rootView: ApplicationsSettingsPane(settingsStore: settingsStore)
                .tint(Color(nsColor: AppBrand.accentColor))
        )
        let applicationsItem = NSTabViewItem(viewController: applicationsController)
        applicationsItem.label = "Apps"
        applicationsItem.image = NSImage(
            systemSymbolName: "app",
            accessibilityDescription: "Apps"
        )
        tabController.addTabViewItem(applicationsItem)

        if let updateController {
            let updatesController = NSHostingController(
                rootView: UpdateSettingsPane(updateController: updateController)
                    .tint(Color(nsColor: AppBrand.accentColor))
            )
            let updatesItem = NSTabViewItem(viewController: updatesController)
            updatesItem.label = "Updates"
            updatesItem.image = NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: "Updates"
            )
            tabController.addTabViewItem(updatesItem)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppBrand.applicationName) Settings"
        window.toolbarStyle = .preference
        window.contentViewController = tabController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.setContentSize(NSSize(width: 660, height: 470))
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    deinit {
        stopMonitoringCommandQ()
    }

    func present() {
        let application = NSApplication.shared
        if window?.isVisible != true {
            activationPolicyBeforePresenting = application.activationPolicy()
            mainMenuBeforePresenting = application.mainMenu
        }
        application.setActivationPolicy(.regular)
        application.mainMenu = settingsMainMenu
        startMonitoringCommandQ()

        loginItemController.refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        application.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        stopMonitoringCommandQ()
        let application = NSApplication.shared
        if application.mainMenu === settingsMainMenu {
            application.mainMenu = mainMenuBeforePresenting
        }
        mainMenuBeforePresenting = nil
        application.setActivationPolicy(activationPolicyBeforePresenting ?? .accessory)
        activationPolicyBeforePresenting = nil
    }

    static func makeSettingsMainMenu(target: AnyObject?) -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu")

        let applicationMenuItem = NSMenuItem(title: AppBrand.applicationName, action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: AppBrand.applicationName)
        applicationMenu.addItem(
            NSMenuItem(
                title: "About \(AppBrand.applicationName)",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""
            )
        )
        applicationMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = target
        settingsItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(settingsItem)
        applicationMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide \(AppBrand.applicationName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        applicationMenu.addItem(hideOthersItem)
        applicationMenu.addItem(
            NSMenuItem(
                title: "Show All",
                action: #selector(NSApplication.unhideAllApplications(_:)),
                keyEquivalent: ""
            )
        )
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(AppBrand.applicationName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        let closeSettingsItem = NSMenuItem(
            title: "Close Settings",
            action: #selector(closeSettings(_:)),
            keyEquivalent: "w"
        )
        closeSettingsItem.target = target
        closeSettingsItem.keyEquivalentModifierMask = [.command]
        fileMenu.addItem(closeSettingsItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        return mainMenu
    }

    static func isCloseSettingsShortcut(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let shortcutModifiers = modifierFlags.intersection([
            .command,
            .option,
            .control,
            .shift,
        ])
        return charactersIgnoringModifiers?.lowercased() == "q"
            && shortcutModifiers == .command
    }

    @objc private func showSettings(_ sender: Any?) {
        present()
    }

    @objc private func closeSettings(_ sender: Any?) {
        dismiss()
    }

    private func startMonitoringCommandQ() {
        guard commandQMonitor == nil else { return }
        commandQMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard Self.isCloseSettingsShortcut(
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags
            ) else {
                return event
            }
            self?.dismiss()
            return nil
        }
    }

    private func stopMonitoringCommandQ() {
        guard let commandQMonitor else { return }
        NSEvent.removeMonitor(commandQMonitor)
        self.commandQMonitor = nil
    }
}
