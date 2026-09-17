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
            "Jostle Enabled",
            "Start at Login",
            "Exclude Current App",
            "Settings…",
            "Quit Jostle"
        ])
        let settingsItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Settings…" }
        )
        XCTAssertEqual(settingsItem.keyEquivalent, ",")
        XCTAssertEqual(settingsItem.keyEquivalentModifierMask, [.command])
    }

    func testEnabledItemTracksEventTapIntent() throws {
        var refreshCount = 0
        let controller = makeController(onRuntimeRefresh: {
            refreshCount += 1
        })
        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Jostle Enabled" }
        )
        XCTAssertEqual(item.state, .on)

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))

        XCTAssertEqual(
            commandItems(in: controller).first { $0.title == "Jostle Enabled" }?.state,
            .off
        )
        XCTAssertEqual(refreshCount, 1)
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

        let item = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Exclude Example Editor" }
        )
        XCTAssertTrue(item.isEnabled)
        XCTAssertEqual(item.state, .off)

        XCTAssertTrue(NSApplication.shared.sendAction(item.action!, to: item.target, from: item))
        XCTAssertEqual(
            settingsStore.settings.excludedApplications[application.key],
            application.name
        )
    }

    func testRecentApplicationExclusionIsAnEnabledToggle() throws {
        let settingsStore = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(settingsStore: settingsStore)
        let application = RunningApplicationInfo(key: "com.example.Game", name: "Example Game")

        controller.setRecentApplication(application)
        var excludeItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Exclude Example Game" }
        )
        XCTAssertTrue(excludeItem.isEnabled)
        XCTAssertEqual(excludeItem.state, .off)

        settingsStore.update { settings in
            settings.setApplicationExcluded(
                key: application.key,
                displayName: application.name,
                excluded: true
            )
        }
        excludeItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Exclude Example Game" }
        )
        XCTAssertTrue(excludeItem.isEnabled)
        XCTAssertEqual(excludeItem.state, .on)

        XCTAssertTrue(
            NSApplication.shared.sendAction(
                excludeItem.action!,
                to: excludeItem.target,
                from: excludeItem
            )
        )
        XCTAssertNil(settingsStore.settings.excludedApplications[application.key])
        XCTAssertEqual(
            commandItems(in: controller).first { $0.title == "Exclude Example Game" }?.state,
            .off
        )
    }

    func testPermissionFailureAddsOneActionableStatusItem() {
        let controller = makeController()
        controller.setRuntimeAvailability(.accessibilityRequired)

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Accessibility Access Required…",
            "Jostle Enabled",
            "Start at Login",
            "Exclude Current App",
            "Settings…",
            "Quit Jostle"
        ])
        XCTAssertFalse(commandItems(in: controller)[1].isEnabled)
        XCTAssertEqual(commandItems(in: controller)[1].state, .off)
    }

    func testEventMonitorFailureOffersRetry() throws {
        var retryCount = 0
        let controller = makeController(onRuntimeRefresh: {
            retryCount += 1
        })
        controller.setRuntimeAvailability(.eventTapUnavailable)

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Event Monitor Unavailable — Retry",
            "Jostle Enabled",
            "Start at Login",
            "Exclude Current App",
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

    private func makeController(
        settingsStore: SettingsStore? = nil,
        loginItemService: LoginItemServicing? = nil,
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
        return StatusMenuController(
            settingsStore: store,
            eventTapController: eventTapController,
            loginItemController: loginItemController,
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

private final class TestLoginItemService: LoginItemServicing {
    var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}
