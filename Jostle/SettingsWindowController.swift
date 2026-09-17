import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(settingsStore: SettingsStore) {
        let tabController = NSTabViewController()
        tabController.tabStyle = .toolbar
        tabController.transitionOptions = []

        let generalController = NSHostingController(
            rootView: GeneralSettingsPane(settingsStore: settingsStore)
        )
        let generalItem = NSTabViewItem(viewController: generalController)
        generalItem.label = "General"
        generalItem.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "General"
        )
        tabController.addTabViewItem(generalItem)

        let exclusionsController = NSHostingController(
            rootView: ExcludedApplicationsSettingsPane(settingsStore: settingsStore)
        )
        let exclusionsItem = NSTabViewItem(viewController: exclusionsController)
        exclusionsItem.label = "Exclusions"
        exclusionsItem.image = NSImage(
            systemSymbolName: "nosign",
            accessibilityDescription: "Exclusions"
        )
        tabController.addTabViewItem(exclusionsItem)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 410),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Jostle Settings"
        window.toolbarStyle = .preference
        window.contentViewController = tabController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.setContentSize(NSSize(width: 660, height: 410))
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
