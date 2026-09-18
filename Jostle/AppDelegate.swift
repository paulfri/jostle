import AppKit
import ApplicationServices
import JostleCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let loginItemController = LoginItemController()
    let pointingDeviceManager = PointingDeviceManager()
    lazy var pointingDeviceBatteryMonitor = PointingDeviceBatteryMonitor { [weak self] name in
        self?.pointingDeviceManager.devices.contains {
            $0.displayName.localizedCaseInsensitiveCompare(name) == .orderedSame
        } ?? false
    }
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
    private var safeMode = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        safeMode = Self.beginLaunchSafetyTracking()
        pointingDeviceManager.onDevicesChanged = { [weak self] devices in
            guard let self else { return }
            LinearMouseMigration.migrateIfNeeded(
                settingsStore: self.settingsStore,
                pointingDevices: devices
            )
        }
        pointingDeviceManager.start()
        LinearMouseMigration.migrateIfNeeded(
            settingsStore: settingsStore,
            pointingDevices: pointingDeviceManager.devices
        )
        let throttleInterval = Self.minimumRefreshIntervalNanoseconds()
        let eventTapController = EventTapController(
            settingsStore: settingsStore,
            pointingDeviceProvider: pointingDeviceManager,
            safeMode: safeMode,
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
        eventTapController.onToggleKeepAwake = { [weak keepAwakeController] in
            keepAwakeController?.toggle()
        }
        let settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            loginItemController: loginItemController,
            globalShortcutController: globalShortcutController,
            pointingDeviceManager: pointingDeviceManager,
            safeMode: safeMode,
            updateController: updateController
        )
        let statusMenuController = StatusMenuController(
            settingsStore: settingsStore,
            eventTapController: eventTapController,
            keepAwakeController: keepAwakeController,
            loginItemController: loginItemController,
            updateController: updateController,
            batteryMonitor: pointingDeviceBatteryMonitor,
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
        pointingDeviceManager.onDeviceDisconnected = { [weak eventTapController] _ in
            eventTapController?.pointingDeviceDidDisconnect()
        }

        self.eventTapController = eventTapController
        self.statusMenuController = statusMenuController
        self.settingsWindowController = settingsWindowController
        if ProcessInfo.processInfo.arguments.contains("--show-settings") || safeMode {
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
        notifications.addObserver(
            self,
            selector: #selector(systemWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        notifications.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
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

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        settingsWindowController?.present()
        return true
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
        pointingDeviceBatteryMonitor.setEnabled(false)
        pointingDeviceManager.onDevicesChanged = nil
        pointingDeviceManager.stop()
        keepAwakeController.shutdown()
        Self.finishLaunchSafetyTracking()
    }

    @objc private func sessionDidBecomeActive(_ notification: Notification) {
        eventTapController?.setSessionActive(true)
        refreshRuntimeHealth()
    }

    @objc private func sessionDidResignActive(_ notification: Notification) {
        eventTapController?.setSessionActive(false)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        eventTapController?.setSessionActive(false)
    }

    @objc private func systemDidWake(_ notification: Notification) {
        eventTapController?.setSessionActive(true)
        refreshRuntimeHealth()
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
            eventTapRequested: eventTapController.eventTapRequested,
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

    private static let cleanExitKey = "Jostle.launch.cleanExit"
    private static let crashCountKey = "Jostle.launch.uncleanCount"

    private static func beginLaunchSafetyTracking() -> Bool {
        let defaults = UserDefaults.standard
        let arguments = ProcessInfo.processInfo.arguments
        let launchModifiers = NSEvent.modifierFlags.intersection([.shift, .option])
        let requestedSafeMode = arguments.contains("--safe-mode")
            || launchModifiers == [.shift, .option]

        let hadPreviousMarker = defaults.object(forKey: cleanExitKey) != nil
        let previousLaunchWasClean = defaults.bool(forKey: cleanExitKey)
        let uncleanCount = hadPreviousMarker && !previousLaunchWasClean
            ? defaults.integer(forKey: crashCountKey) + 1
            : 0
        defaults.set(uncleanCount, forKey: crashCountKey)
        defaults.set(false, forKey: cleanExitKey)
        return requestedSafeMode || uncleanCount >= 3
    }

    private static func finishLaunchSafetyTracking() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: cleanExitKey)
        defaults.set(0, forKey: crashCountKey)
    }

    private static func minimumRefreshIntervalNanoseconds() -> UInt64 {
        let interval = NSScreen.screens.reduce(1.0 / 60.0) { current, screen in
            min(current, screen.minimumRefreshInterval)
        }
        return UInt64(interval * 1_000_000_000)
    }
}
