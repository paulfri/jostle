import AppKit
import ApplicationServices
import JostleCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let loginItemController = LoginItemController()
    lazy var keepAwakeController = KeepAwakeController(settingsStore: settingsStore)
    lazy var globalShortcutController = GlobalShortcutController(settingsStore: settingsStore)
    private let updateController: SparkleUpdateController? = {
#if JOSTLE_DEVELOPMENT
        nil
#else
        SparkleUpdateController()
#endif
    }()
    private var eventTapController: EventTapController?
    private var statusMenuController: StatusMenuController?
    private var settingsWindowController: SettingsWindowController?
    private var runtimeHealthTimer: Timer?
    private let screenLockMonitor = ScreenLockMonitor()
    private let powerSourceMonitor = PowerSourceMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let throttleInterval = Self.minimumRefreshIntervalNanoseconds()
        let eventTapController = EventTapController(
            settingsStore: settingsStore,
            gestureConfiguration: GestureConfiguration(
                moveThrottleInterval: throttleInterval,
                resizeThrottleInterval: throttleInterval
            )
        )
        let keepAwakeController = self.keepAwakeController
        let globalShortcutController = self.globalShortcutController
        globalShortcutController.onTrigger = { [weak keepAwakeController] in
            keepAwakeController?.toggle()
        }
        let settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            loginItemController: loginItemController,
            globalShortcutController: globalShortcutController,
            updateController: updateController
        )
        let statusMenuController = StatusMenuController(
            settingsStore: settingsStore,
            eventTapController: eventTapController,
            keepAwakeController: keepAwakeController,
            loginItemController: loginItemController,
            updateController: updateController,
            onRuntimeRefresh: { [weak self] in
                self?.refreshRuntimeHealth()
            },
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

        _ = Self.requestAccessibilityAccess()
        refreshRuntimeHealth()
        let runtimeHealthTimer = Timer(
            timeInterval: 1.5,
            target: self,
            selector: #selector(checkRuntimeHealth(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(runtimeHealthTimer, forMode: .common)
        self.runtimeHealthTimer = runtimeHealthTimer

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

        screenLockMonitor.onLock = { [weak keepAwakeController] in
            keepAwakeController?.screenDidLock()
        }
        screenLockMonitor.onUnlock = { [weak keepAwakeController] in
            keepAwakeController?.screenDidUnlock()
        }
        screenLockMonitor.start()
        powerSourceMonitor.onChange = { [weak keepAwakeController] previous, current in
            keepAwakeController?.powerSourceDidChange(from: previous, to: current)
        }
        powerSourceMonitor.start()

        if settingsStore.settings.keepAwakeActivateAtLaunch {
            keepAwakeController.startDefault()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            do {
                let command = try KeepAwakeURLCommandParser.parse(url)
                keepAwakeController.perform(command)
            } catch {
                keepAwakeController.reportAutomationError(error)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        screenLockMonitor.stop()
        powerSourceMonitor.stop()
        runtimeHealthTimer?.invalidate()
        eventTapController?.stop()
        keepAwakeController.shutdown()
    }

    @objc private func sessionDidBecomeActive(_ notification: Notification) {
        eventTapController?.setSessionActive(true)
        refreshRuntimeHealth()
    }

    @objc private func sessionDidResignActive(_ notification: Notification) {
        eventTapController?.setSessionActive(false)
    }

    @objc private func checkRuntimeHealth(_ timer: Timer) {
        refreshRuntimeHealth()
    }

    private func refreshRuntimeHealth() {
        guard let eventTapController, let statusMenuController else { return }

        let trusted = AXIsProcessTrusted()
        let operational: Bool
        if trusted {
            operational = eventTapController.ensureOperational()
        } else {
            eventTapController.suspend()
            operational = false
        }
        let availability = RuntimeHealthPolicy.availability(
            accessibilityTrusted: trusted,
            eventTapRequested: eventTapController.requestedEnabled,
            eventTapOperational: operational && eventTapController.isOperational
        )
        statusMenuController.setRuntimeAvailability(availability)
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
