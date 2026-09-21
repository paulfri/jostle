import AppKit
import XCTest
@testable import Jostle

final class CommandKeyRecoveryControllerTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "fm.pau.jostle.command-recovery-tests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecoveryRequiresInputCustomizationAndPerAppOptIn() {
        let store = SettingsStore(userDefaults: userDefaults)
        let scheduler = TestRecoveryScheduler()
        let controller = makeController(store: store, scheduler: scheduler)

        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        XCTAssertTrue(scheduler.actions.isEmpty)

        store.update { $0.inputCustomization.isEnabled = true }
        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        XCTAssertTrue(scheduler.actions.isEmpty)

        store.update {
            $0.setCommandKeyRecovery(
                true,
                forApplicationKey: "eqgame.exe",
                displayName: "EverQuest"
            )
        }
        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        XCTAssertEqual(scheduler.actions.map(\.delay), [0.08])
    }

    func testRecoveryPostsBalancedCommandEventsToActivatedProcess() throws {
        let store = configuredStore()
        let scheduler = TestRecoveryScheduler()
        var postedEvents: [PostedCommandEvent] = []
        let controller = makeController(
            store: store,
            scheduler: scheduler,
            eventPoster: { processIdentifier, isKeyDown in
                postedEvents.append(PostedCommandEvent(
                    processIdentifier: processIdentifier,
                    isKeyDown: isKeyDown
                ))
            }
        )

        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        try scheduler.runNext()

        XCTAssertEqual(postedEvents, [
            PostedCommandEvent(processIdentifier: 42, isKeyDown: true),
        ])
        XCTAssertEqual(scheduler.actions.map(\.delay), [0.03])

        try scheduler.runNext()
        XCTAssertEqual(postedEvents, [
            PostedCommandEvent(processIdentifier: 42, isKeyDown: true),
            PostedCommandEvent(processIdentifier: 42, isKeyDown: false),
        ])
    }

    func testClaimedRecoveryAlwaysPostsItsMatchingRelease() throws {
        let store = configuredStore()
        let scheduler = TestRecoveryScheduler()
        var postedEvents: [PostedCommandEvent] = []
        let controller = makeController(
            store: store,
            scheduler: scheduler,
            eventPoster: { processIdentifier, isKeyDown in
                postedEvents.append(PostedCommandEvent(
                    processIdentifier: processIdentifier,
                    isKeyDown: isKeyDown
                ))
            }
        )

        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        try scheduler.runNext()
        controller.setSessionActive(false)
        try scheduler.runNext()

        XCTAssertEqual(postedEvents, [
            PostedCommandEvent(processIdentifier: 42, isKeyDown: true),
            PostedCommandEvent(processIdentifier: 42, isKeyDown: false),
        ])
    }

    func testRecoveryWaitsUntilPhysicalModifiersAreReleased() throws {
        let store = configuredStore()
        let scheduler = TestRecoveryScheduler()
        var heldModifiers: NSEvent.ModifierFlags = [.command]
        var postedEvents: [PostedCommandEvent] = []
        let controller = makeController(
            store: store,
            scheduler: scheduler,
            modifierFlags: { heldModifiers },
            eventPoster: { processIdentifier, isKeyDown in
                postedEvents.append(PostedCommandEvent(
                    processIdentifier: processIdentifier,
                    isKeyDown: isKeyDown
                ))
            }
        )

        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        try scheduler.runNext()

        XCTAssertTrue(postedEvents.isEmpty)
        XCTAssertEqual(scheduler.actions.map(\.delay), [0.05])

        heldModifiers = []
        try scheduler.runNext()
        XCTAssertEqual(postedEvents, [
            PostedCommandEvent(processIdentifier: 42, isKeyDown: true),
        ])
        try scheduler.runNext()
        XCTAssertEqual(postedEvents.last?.isKeyDown, false)
    }

    func testLaterActivationCancelsPendingRecovery() throws {
        let store = configuredStore()
        let scheduler = TestRecoveryScheduler()
        var postedEvents: [PostedCommandEvent] = []
        let controller = makeController(
            store: store,
            scheduler: scheduler,
            eventPoster: { processIdentifier, isKeyDown in
                postedEvents.append(PostedCommandEvent(
                    processIdentifier: processIdentifier,
                    isKeyDown: isKeyDown
                ))
            }
        )

        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        controller.applicationDidActivate(
            processIdentifier: 99,
            applicationKey: "com.example.Editor"
        )
        try scheduler.runNext()

        XCTAssertTrue(postedEvents.isEmpty)
    }

    func testSafeModeAndInactiveSessionsSuppressRecovery() throws {
        let store = configuredStore()
        let safeModeScheduler = TestRecoveryScheduler()
        let safeModeController = makeController(
            store: store,
            scheduler: safeModeScheduler,
            safeMode: true
        )
        safeModeController.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        XCTAssertTrue(safeModeScheduler.actions.isEmpty)

        let scheduler = TestRecoveryScheduler()
        var postedEvents: [PostedCommandEvent] = []
        let controller = makeController(
            store: store,
            scheduler: scheduler,
            eventPoster: { processIdentifier, isKeyDown in
                postedEvents.append(PostedCommandEvent(
                    processIdentifier: processIdentifier,
                    isKeyDown: isKeyDown
                ))
            }
        )
        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        controller.setSessionActive(false)
        try scheduler.runNext()

        XCTAssertTrue(postedEvents.isEmpty)
    }

    func testRecoveryRechecksSettingsAndFrontmostProcessBeforePosting() throws {
        let store = configuredStore()
        let scheduler = TestRecoveryScheduler()
        var frontmostProcessIdentifier: pid_t? = 42
        var postedEvents: [PostedCommandEvent] = []
        let controller = makeController(
            store: store,
            scheduler: scheduler,
            frontmostProcessIdentifier: { frontmostProcessIdentifier },
            eventPoster: { processIdentifier, isKeyDown in
                postedEvents.append(PostedCommandEvent(
                    processIdentifier: processIdentifier,
                    isKeyDown: isKeyDown
                ))
            }
        )

        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        frontmostProcessIdentifier = 99
        try scheduler.runNext()
        XCTAssertTrue(postedEvents.isEmpty)

        frontmostProcessIdentifier = 42
        controller.applicationDidActivate(
            processIdentifier: 42,
            applicationKey: "eqgame.exe"
        )
        store.update { $0.inputCustomization.isEnabled = false }
        try scheduler.runNext()
        XCTAssertTrue(postedEvents.isEmpty)
    }

    private func configuredStore() -> SettingsStore {
        let store = SettingsStore(userDefaults: userDefaults)
        store.update {
            $0.inputCustomization.isEnabled = true
            $0.setCommandKeyRecovery(
                true,
                forApplicationKey: "eqgame.exe",
                displayName: "EverQuest"
            )
        }
        return store
    }

    private func makeController(
        store: SettingsStore,
        scheduler: TestRecoveryScheduler,
        safeMode: Bool = false,
        frontmostProcessIdentifier: @escaping () -> pid_t? = { 42 },
        modifierFlags: @escaping () -> NSEvent.ModifierFlags = { [] },
        eventPoster: @escaping CommandKeyRecoveryController.EventPoster = { _, _ in }
    ) -> CommandKeyRecoveryController {
        CommandKeyRecoveryController(
            settingsStore: store,
            safeMode: safeMode,
            notificationCenter: NotificationCenter(),
            frontmostProcessIdentifier: frontmostProcessIdentifier,
            modifierFlags: modifierFlags,
            scheduler: scheduler.schedule(delay:action:),
            eventPoster: eventPoster
        )
    }
}

private struct PostedCommandEvent: Equatable {
    let processIdentifier: pid_t
    let isKeyDown: Bool
}

private final class TestRecoveryScheduler {
    struct Action {
        let delay: TimeInterval
        let body: () -> Void
    }

    private(set) var actions: [Action] = []

    func schedule(delay: TimeInterval, action: @escaping () -> Void) {
        actions.append(Action(delay: delay, body: action))
    }

    func runNext() throws {
        guard !actions.isEmpty else {
            throw TestRecoverySchedulerError.noScheduledAction
        }
        actions.removeFirst().body()
    }
}

private enum TestRecoverySchedulerError: Error {
    case noScheduledAction
}
