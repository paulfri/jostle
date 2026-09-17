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

    func testSwiftUISettingsSceneInstallsTheStandardSettingsAction() {
        XCTAssertNotNil(
            NSApplication.shared.target(
                forAction: Selector(("showSettingsWindow:")),
                to: nil,
                from: nil
            )
        )
    }

    func testMenuContainsOnlyEssentialCommands() throws {
        let controller = makeController()

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Jostle Enabled",
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

    func testRecentApplicationAndSettingsChangesRefreshMenu() throws {
        let settingsStore = SettingsStore(userDefaults: userDefaults)
        let controller = makeController(settingsStore: settingsStore)
        let application = RunningApplicationInfo(key: "com.example.Game", name: "Example Game")

        controller.setRecentApplication(application)
        var excludeItem = try XCTUnwrap(
            commandItems(in: controller).first { $0.title == "Exclude Example Game" }
        )
        XCTAssertTrue(excludeItem.isEnabled)

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
        XCTAssertFalse(excludeItem.isEnabled)
    }

    func testPermissionFailureAddsOneActionableStatusItem() {
        let controller = makeController()
        controller.setAccessibilityAvailable(false)

        XCTAssertEqual(commandItems(in: controller).map(\.title), [
            "Accessibility Access Required",
            "Jostle Enabled",
            "Exclude Current App",
            "Settings…",
            "Quit Jostle"
        ])
        XCTAssertFalse(commandItems(in: controller)[1].isEnabled)
        XCTAssertEqual(commandItems(in: controller)[1].state, .off)
    }

    private func makeController(settingsStore: SettingsStore? = nil) -> StatusMenuController {
        let store = settingsStore ?? SettingsStore(userDefaults: userDefaults)
        let eventTapController = EventTapController(
            settingsStore: store,
            gestureConfiguration: GestureConfiguration(
                moveThrottleInterval: 1,
                resizeThrottleInterval: 1
            )
        )
        return StatusMenuController(
            settingsStore: store,
            eventTapController: eventTapController
        )
    }

    private func commandItems(in controller: StatusMenuController) -> [NSMenuItem] {
        controller.renderedMenu.items.filter { !$0.isSeparatorItem }
    }
}
