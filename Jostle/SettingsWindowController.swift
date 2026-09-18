import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let loginItemController: LoginItemController

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
        globalShortcutController: GlobalShortcutController,
        pointingDeviceManager: PointingDeviceManager,
        safeMode: Bool = false,
        updateController: SparkleUpdateController? = nil
    ) {
        self.loginItemController = loginItemController
        let tabController = NSTabViewController()
        tabController.tabStyle = .toolbar
        tabController.transitionOptions = []

        let generalController = NSHostingController(
            rootView: GeneralSettingsPane(
                settingsStore: settingsStore,
                loginItemController: loginItemController
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func present() {
        loginItemController.refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
