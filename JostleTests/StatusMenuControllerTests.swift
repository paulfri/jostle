import AppKit
import JostleCore
import XCTest
@testable import Jostle

final class StatusMenuControllerTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "fm.pau.jostle.menu-tests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSettingsMainMenuContainsCloseCommand() throws {
        let menu = SettingsWindowController.makeSettingsMainMenu(target: nil)
        let fileMenu = try XCTUnwrap(
            menu.items.first { $0.title == "File" }?.submenu
        )
        let closeItem = try XCTUnwrap(
            fileMenu.items.first { $0.title == "Close Settings" }
        )

        XCTAssertNotNil(closeItem.action)
        XCTAssertEqual(closeItem.keyEquivalent, "w")
        XCTAssertEqual(closeItem.keyEquivalentModifierMask, [.command])
    }

    func testCommandQIsReservedForClosingSettings() {
        XCTAssertTrue(
            SettingsWindowController.isCloseSettingsShortcut(
                charactersIgnoringModifiers: "q",
                modifierFlags: [.command]
            )
        )
        XCTAssertTrue(
            SettingsWindowController.isCloseSettingsShortcut(
                charactersIgnoringModifiers: "Q",
                modifierFlags: [.command, .capsLock]
            )
        )
        XCTAssertFalse(
            SettingsWindowController.isCloseSettingsShortcut(
                charactersIgnoringModifiers: "q",
                modifierFlags: [.command, .shift]
            )
        )
        XCTAssertFalse(
            SettingsWindowController.isCloseSettingsShortcut(
                charactersIgnoringModifiers: "w",
                modifierFlags: [.command]
            )
        )
    }

    func testSettingsItemInvokesOwnedWindowPresenter() throws {
        var presentationCount = 0
        let controller = makeController(onOpenSettings: {
            presentationCount += 1
        })
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Settings…" }
        )

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))
        XCTAssertEqual(presentationCount, 1)
    }

    func testMenuContainsOnlyEssentialCommands() throws {
        let controller = makeController()

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Window Features Enabled",
            "Input Customizations Enabled",
            "Keep Mac Awake",
            "Keep Awake For",
            "Allow Display to Sleep",
            "Start at Login",
            "Current App",
            "Settings…",
            "Quit Jostle"
        ])
        let settingsItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Settings…" }
        )
        XCTAssertEqual(settingsItem.keyEquivalent, ",")
        XCTAssertEqual(settingsItem.keyEquivalentModifierMask, [.command])
    }

    func testUpdateItemTracksAvailabilityAndInvokesUpdater() throws {
        let updateController = TestUpdateController()
        let controller = makeController(updateController: updateController)
        var item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Check for Updates…" }
        )
        XCTAssertTrue(item.isEnabled)

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))
        XCTAssertEqual(updateController.checkCount, 1)

        updateController.canCheckForUpdates = false
        controller.refresh()
        item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Check for Updates…" }
        )
        XCTAssertFalse(item.isEnabled)
    }

    func testEnabledItemTracksEventTapIntent() throws {
        var refreshCount = 0
        let controller = makeController(onRuntimeRefresh: {
            refreshCount += 1
        })
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Window Features Enabled" }
        )
        XCTAssertEqual(item.state, .on)

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))

        XCTAssertEqual(
            commandItems(in: controller).first { $0.title == "Window Features Enabled" }?.state,
            .off
        )
        XCTAssertEqual(refreshCount, 1)
    }

    func testInputCustomizationMenuItemUpdatesIndependentSetting() throws {
        let store = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(settingsStore: store)
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Input Customizations Enabled" }
        )
        XCTAssertEqual(item.state, .off)

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))

        XCTAssertTrue(store.settings.inputCustomization.isEnabled)
        XCTAssertEqual(
            commandItems(in: controller)
                .first { $0.title == "Input Customizations Enabled" }?.state,
            .on
        )
    }

    func testStartAtLoginMenuItemTogglesTheLoginItemService() throws {
        let service = TestLoginItemService()
        let controller = makeController(loginItemService: service)
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Start at Login" }
        )
        XCTAssertEqual(item.state, .off)

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))

        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(
            commandItems(in: controller).first { $0.title == "Start at Login" }?.state,
            .on
        )
    }

    func testMenuOpeningTargetsCurrentApplicationWithoutAccessibility() throws {
        let application = RunningApplicationInfo(key: "com.example.Editor", name: "Example Editor")
        let settingsStore = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(
            settingsStore: settingsStore,
            currentApplicationProvider: { application }
        )
        controller.setRuntimeAvailability(.accessibilityRequired)

        controller.menuWillOpen(controller.renderedMenu)

        let appItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "App: Example Editor" }
        )
        let windowControlsItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Window Controls")
        )
        XCTAssertTrue(appItem.isEnabled)
        XCTAssertEqual(windowControlsItem.state, .on)

        XCTAssertTrue(
            NSApplication.shared.sendAction(
                windowControlsItem.action!,
                to: windowControlsItem.target,
                from: windowControlsItem
            )
        )
        XCTAssertEqual(
            settingsStore.settings.applicationRules[application.key]?.windowControls,
            .disabled
        )
    }

    func testRecentApplicationFeaturesAreIndependentToggles() throws {
        let settingsStore = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(settingsStore: settingsStore)
        let application = RunningApplicationInfo(key: "com.example.Game", name: "Example Game")

        controller.setRecentApplication(application)
        var appItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "App: Example Game" }
        )
        var windowControlsItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Window Controls")
        )
        var focusItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Focus Follows Pointer")
        )
        var commandRecoveryItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Reset modifiers when switching")
        )
        XCTAssertEqual(windowControlsItem.state, .on)
        XCTAssertEqual(focusItem.state, .off)
        XCTAssertEqual(commandRecoveryItem.state, .off)

        XCTAssertTrue(
            NSApplication.shared.sendAction(
                focusItem.action!,
                to: focusItem.target,
                from: focusItem
            )
        )
        XCTAssertEqual(
            settingsStore.settings.applicationRules[application.key]?.focusFollowsPointer,
            .enabled
        )
        XCTAssertTrue(
            NSApplication.shared.sendAction(
                commandRecoveryItem.action!,
                to: commandRecoveryItem.target,
                from: commandRecoveryItem
            )
        )
        XCTAssertTrue(
            settingsStore.settings.commandKeyRecoveryEnabled(
                forApplicationKey: application.key
            )
        )

        appItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "App: Example Game" }
        )
        windowControlsItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Window Controls")
        )
        focusItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Focus Follows Pointer")
        )
        commandRecoveryItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Reset modifiers when switching")
        )
        XCTAssertEqual(windowControlsItem.state, .on)
        XCTAssertEqual(focusItem.state, .on)
        XCTAssertEqual(commandRecoveryItem.state, .on)

        let defaultsItem = try XCTUnwrap(
            appItem.submenu?.item(withTitle: "Use App Defaults")
        )
        XCTAssertTrue(
            NSApplication.shared.sendAction(
                defaultsItem.action!,
                to: defaultsItem.target,
                from: defaultsItem
            )
        )
        XCTAssertNil(settingsStore.settings.applicationRules[application.key])
        XCTAssertFalse(
            settingsStore.settings.focusFollowsPointerEnabled(
                forApplicationKey: application.key
            )
        )
        XCTAssertFalse(
            settingsStore.settings.commandKeyRecoveryEnabled(
                forApplicationKey: application.key
            )
        )
    }

    func testPermissionFailureAddsOneActionableStatusItem() {
        let controller = makeController()
        controller.setRuntimeAvailability(.accessibilityRequired)

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Accessibility Access Required…",
            "Window Features Enabled",
            "Input Customizations Enabled",
            "Keep Mac Awake",
            "Keep Awake For",
            "Allow Display to Sleep",
            "Start at Login",
            "Current App",
            "Settings…",
            "Quit Jostle"
        ])
        XCTAssertFalse(commandItems(in: controller)[1].isEnabled)
        XCTAssertEqual(commandItems(in: controller)[1].state, .off)
    }

    func testStatusIconUsesCalmFrameTemplateWithStatefulCenter() throws {
        let idle = StatusIconRenderer.presentation(
            applicationName: "Jostle",
            windowGesturesAvailable: true,
            centerState: .none,
            dimWhenInactive: false,
            indicatorStyle: .normal
        )
        let awake = StatusIconRenderer.presentation(
            applicationName: "Jostle",
            windowGesturesAvailable: false,
            centerState: .awake,
            dimWhenInactive: true,
            indicatorStyle: .normal
        )
        let colored = StatusIconRenderer.presentation(
            applicationName: "Jostle",
            windowGesturesAvailable: true,
            centerState: .awake,
            dimWhenInactive: false,
            indicatorStyle: .coloredGreen
        )

        XCTAssertTrue(idle.image.isTemplate)
        XCTAssertEqual(idle.image.size, NSSize(width: 16, height: 16))
        XCTAssertEqual(idle.image.size.width, idle.image.size.height)
        XCTAssertEqual(
            StatusIconRenderer.frameCenterlineBounds.insetBy(
                dx: -StatusIconRenderer.frameLineWidth / 2,
                dy: -StatusIconRenderer.frameLineWidth / 2
            ),
            NSRect(origin: .zero, size: StatusIconRenderer.canvasSize)
        )
        XCTAssertEqual(StatusIconRenderer.centerSymbolSize, NSSize(width: 12, height: 12))
        let awakeSymbol = try XCTUnwrap(
            NSImage(
                systemSymbolName: "bolt.fill",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: StatusIconRenderer.centerSymbolPointSize(for: "bolt.fill"),
                    weight: .semibold
                )
            )
        )
        XCTAssertLessThanOrEqual(awakeSymbol.size.width, StatusIconRenderer.centerSymbolSize.width)
        XCTAssertLessThanOrEqual(awakeSymbol.size.height, StatusIconRenderer.centerSymbolSize.height)
        XCTAssertEqual(
            StatusIconRenderer.centerSymbolFrame(
                in: NSRect(x: 10, y: 3, width: 16, height: 16)
            ),
            NSRect(x: 12, y: 5, width: 12, height: 12)
        )
        XCTAssertNil(idle.overlaySymbolName)
        XCTAssertNil(idle.iconTintColor)

        XCTAssertTrue(awake.image.isTemplate)
        XCTAssertEqual(awake.overlaySymbolName, "bolt.fill")
        XCTAssertTrue(awake.overlayTintColor?.isEqual(NSColor.labelColor) == true)
        XCTAssertFalse(awake.shouldDim, "Keep Awake must remain visible without Accessibility")

        XCTAssertTrue(colored.image.isTemplate)
        XCTAssertNil(colored.overlaySymbolName)
        XCTAssertTrue(colored.iconTintColor?.isEqual(NSColor.systemGreen) == true)
    }

    func testStatusIconRepresentsPausedAndAttentionStates() {
        let paused = StatusIconRenderer.presentation(
            applicationName: "Jostle",
            windowGesturesAvailable: false,
            centerState: .paused,
            dimWhenInactive: true,
            indicatorStyle: .normal
        )
        let attention = StatusIconRenderer.presentation(
            applicationName: "Jostle",
            windowGesturesAvailable: true,
            centerState: .attention,
            dimWhenInactive: false,
            indicatorStyle: .normal
        )

        XCTAssertNil(paused.overlaySymbolName)
        XCTAssertFalse(paused.shouldDim)
        XCTAssertEqual(
            paused.image.accessibilityDescription,
            "Jostle, Keep Awake paused while locked"
        )
        XCTAssertEqual(attention.overlaySymbolName, "exclamationmark")
        XCTAssertEqual(
            attention.image.accessibilityDescription,
            "Jostle, Keep Awake needs attention"
        )
    }

    func testAccessibilityFailureDoesNotDisableKeepAwake() throws {
        let controller = makeController()
        controller.setRuntimeAvailability(.accessibilityRequired)
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Keep Mac Awake" }
        )

        XCTAssertTrue(item.isEnabled)
        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))

        let activeItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title.hasPrefix("Keep Mac Awake —") }
        )
        XCTAssertEqual(activeItem.state, .on)
        XCTAssertTrue(activeItem.isEnabled)
    }

    func testEventMonitorFailureOffersRetry() throws {
        var retryCount = 0
        let controller = makeController(onRuntimeRefresh: {
            retryCount += 1
        })
        controller.setRuntimeAvailability(.eventTapUnavailable)

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Event Monitor Unavailable — Retry",
            "Window Features Enabled",
            "Input Customizations Enabled",
            "Keep Mac Awake",
            "Keep Awake For",
            "Allow Display to Sleep",
            "Start at Login",
            "Current App",
            "Settings…",
            "Quit Jostle"
        ])
        let retryItem = try XCTUnwrap(commandItems(in: controller).first)
        XCTAssertTrue(
            NSApplication.shared.sendAction(
                retryItem.action!,
                to: retryItem.target,
                from: retryItem
            )
        )
        XCTAssertEqual(retryCount, 1)
    }

    func testKeepAwakeMenuStartsDefaultAndPresetSessions() throws {
        let controller = makeController()
        let toggle = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Keep Mac Awake" }
        )

        XCTAssertTrue(NSApplication.shared.sendAction(toggle.action!, to: toggle.target, from: toggle))
        var activeItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title.hasPrefix("Keep Mac Awake —") }
        )
        XCTAssertEqual(activeItem.state, .on)
        XCTAssertTrue(activeItem.title.contains("Indefinitely"))

        let durationRoot = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Keep Awake For" }
        )
        let oneHour = try XCTUnwrap(durationRoot.submenu?.item(withTitle: "1 Hour"))
        XCTAssertTrue(NSApplication.shared.sendAction(oneHour.action!, to: oneHour.target, from: oneHour))
        activeItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title.hasPrefix("Keep Mac Awake —") }
        )
        XCTAssertTrue(activeItem.title.contains("1h"))
    }

    func testConfiguredStatusClickTogglesKeepAwake() {
        let store = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(settingsStore: store)

        controller.handleStatusItemClick(type: .rightMouseUp)
        XCTAssertNotNil(
            commandItems(in: controller).first { $0.title.contains("Indefinitely") }
        )

        controller.handleStatusItemClick(type: .rightMouseUp)
        store.update { $0.keepAwakeActivateOnLeftClick = true }
        controller.handleStatusItemClick(type: .leftMouseUp)
        XCTAssertNotNil(
            commandItems(in: controller).first { $0.title.contains("Indefinitely") }
        )
    }

    func testAllowDisplaySleepMenuItemUpdatesSettings() throws {
        let store = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(settingsStore: store)
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Allow Display to Sleep" }
        )

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))

        XCTAssertTrue(store.settings.keepAwakeAllowDisplaySleep)
        XCTAssertEqual(
            commandItems(in: controller).first { $0.title == "Allow Display to Sleep" }?.state,
            .on
        )
    }

    func testBatteryReadingAppearsWhenDisplayModeAllowsIt() {
        let store = SettingsStore(userDefaults: userDefaults)
        store.update {
            $0.inputCustomization.batteryDisplayMode = .always
        }
        let batteryMonitor = TestPointingDeviceBatteryMonitor(readings: [
            PointingDeviceBatteryReading(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                deviceName: "MX Master 3S",
                level: 72
            ),
        ])
        let controller = makeController(
            settingsStore: store,
            batteryMonitor: batteryMonitor
        )

        XCTAssertTrue(batteryMonitor.isEnabled)
        XCTAssertEqual(controller.renderedStatusTitle, " 72%")
        XCTAssertNotNil(
            commandItems(in: controller).first {
                $0.title == "MX Master 3S Battery: 72%"
            }
        )
    }

    private func makeController(
        settingsStore: SettingsStore? = nil,
        loginItemService: LoginItemServicing? = nil,
        updateController: UpdateControlling? = nil,
        batteryMonitor: PointingDeviceBatteryMonitoring? = nil,
        currentApplicationProvider: @escaping () -> RunningApplicationInfo? = { nil },
        onRuntimeRefresh: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) -> StatusMenuController {
        let store = settingsStore ?? SettingsStore(userDefaults: userDefaults)
        let eventTapController = EventTapController(
            settingsStore: store,
            gestureConfiguration: GestureConfiguration(
                moveThrottleInterval: 1,
                resizeThrottleInterval: 1
            )
        )
        let loginItemController = LoginItemController(
            service: loginItemService ?? TestLoginItemService()
        )
        let keepAwakeController = KeepAwakeController(
            settingsStore: store,
            powerAssertion: TestPowerAssertion(),
            timer: TestKeepAwakeTimer(),
            notifier: TestCompletionNotifier()
        )
        return StatusMenuController(
            settingsStore: store,
            eventTapController: eventTapController,
            keepAwakeController: keepAwakeController,
            loginItemController: loginItemController,
            updateController: updateController,
            batteryMonitor: batteryMonitor,
            currentApplicationProvider: currentApplicationProvider,
            applicationName: "Jostle",
            onRuntimeRefresh: onRuntimeRefresh,
            onOpenSettings: onOpenSettings
        )
    }

    private func commandItems(in controller: StatusMenuController) -> [NSMenuItem] {
        controller.renderedMenu.items.filter { !$0.isSeparatorItem }
    }
}

private final class TestPointingDeviceBatteryMonitor: PointingDeviceBatteryMonitoring {
    var onChange: (() -> Void)?
    var readings: [PointingDeviceBatteryReading]
    private(set) var isEnabled = false

    init(readings: [PointingDeviceBatteryReading]) {
        self.readings = readings
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}

private final class TestUpdateController: UpdateControlling {
    var canCheckForUpdates = true
    var automaticallyChecksForUpdates = false
    private(set) var checkCount = 0

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        checkCount += 1
    }
}

private final class TestLoginItemService: LoginItemServicing {
    var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}
