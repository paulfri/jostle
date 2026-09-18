import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let loginItemController: LoginItemController

    init(
        settingsStore: SettingsStore,
        loginItemController: LoginItemController,
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
            accessibilityDescription: "General"
        )
        tabController.addTabViewItem(generalItem)

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

        let exclusionsController = NSHostingController(
            rootView: ExcludedApplicationsSettingsPane(settingsStore: settingsStore)
                .tint(Color(nsColor: AppBrand.accentColor))
        )
        let exclusionsItem = NSTabViewItem(viewController: exclusionsController)
        exclusionsItem.label = "Exclusions"
        exclusionsItem.image = NSImage(
            systemSymbolName: "nosign",
            accessibilityDescription: "Exclusions"
        )
        tabController.addTabViewItem(exclusionsItem)

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
