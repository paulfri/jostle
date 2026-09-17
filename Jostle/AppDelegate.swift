import AppKit
import ApplicationServices
import JostleCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let loginItemController = LoginItemController()
    private var eventTapController: EventTapController?
    private var statusMenuController: StatusMenuController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let throttleInterval = Self.minimumRefreshIntervalNanoseconds()
        let eventTapController = EventTapController(
            settingsStore: settingsStore,
            gestureConfiguration: GestureConfiguration(
                moveThrottleInterval: throttleInterval,
                resizeThrottleInterval: throttleInterval
            )
        )
        let settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            loginItemController: loginItemController
        )
        let statusMenuController = StatusMenuController(
            settingsStore: settingsStore,
            eventTapController: eventTapController,
            loginItemController: loginItemController,
            onOpenSettings: { [weak settingsWindowController] in
                settingsWindowController?.present()
            }
        )
        eventTapController.onRecentApplication = { [weak statusMenuController] application in
            DispatchQueue.main.async {
                statusMenuController?.setRecentApplication(application)
            }
        }

        self.eventTapController = eventTapController
        self.statusMenuController = statusMenuController
        self.settingsWindowController = settingsWindowController
        if ProcessInfo.processInfo.arguments.contains("--show-settings") {
            DispatchQueue.main.async {
                settingsWindowController.present()
            }
        }

        let trusted = Self.requestAccessibilityAccess()
        let started = trusted && eventTapController.start()
        statusMenuController.setAccessibilityAvailable(started)

        let notifications = NSWorkspace.shared.notificationCenter
        notifications.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive(_:)),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        notifications.addObserver(
            self,
            selector: #selector(sessionDidResignActive(_:)),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        eventTapController?.stop()
    }

    @objc private func sessionDidBecomeActive(_ notification: Notification) {
        eventTapController?.setSessionActive(true)
    }

    @objc private func sessionDidResignActive(_ notification: Notification) {
        eventTapController?.setSessionActive(false)
    }

    private static func requestAccessibilityAccess() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func minimumRefreshIntervalNanoseconds() -> UInt64 {
        let interval = NSScreen.screens.reduce(1.0 / 60.0) { current, screen in
            min(current, screen.minimumRefreshInterval)
        }
        return UInt64(interval * 1_000_000_000)
    }
}
