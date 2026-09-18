import Foundation
import JostleCore
import XCTest
@testable import Jostle

final class KeepAwakeControllerTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "fm.pau.jostle.keep-awake-tests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultIndefiniteSessionAcquiresAndReleasesAssertion() {
        let harness = makeHarness()

        harness.controller.startDefault()

        XCTAssertEqual(harness.controller.state, .active(.indefinitely))
        XCTAssertTrue(harness.controller.isEnabled)
        XCTAssertTrue(harness.controller.isPreventingSleep)
        XCTAssertEqual(harness.assertion.acquireValues, [false])
        XCTAssertEqual(harness.timer.startCalls.count, 0)

        harness.controller.stop()

        XCTAssertEqual(harness.controller.state, .inactive)
        XCTAssertFalse(harness.controller.isEnabled)
        XCTAssertEqual(harness.assertion.releaseCount, 1)
    }

    func testFiniteSessionUsesSelectedTimerAndNotifiesAtCompletion() {
        let harness = makeHarness()
        harness.store.update { $0.keepAwakeUseImprovedTimer = false }

        harness.controller.start(.seconds(90))

        XCTAssertEqual(harness.timer.startCalls, [.init(duration: 90, improved: false)])
        XCTAssertEqual(harness.notifier.prepareCount, 1)

        harness.timer.complete()

        XCTAssertEqual(harness.controller.state, .inactive)
        XCTAssertEqual(harness.assertion.releaseCount, 1)
        XCTAssertEqual(harness.notifier.notificationCount, 1)
    }

    func testScreenLockPausesAssertionAndCountdownThenResumes() {
        let harness = makeHarness()
        harness.store.update { $0.keepAwakeAllowSleepWhenLocked = true }
        harness.controller.start(.seconds(600))
        harness.timer.remainingTime = 420

        harness.controller.screenDidLock()

        XCTAssertEqual(harness.controller.state, .paused(.seconds(600), remaining: 420))
        XCTAssertTrue(harness.controller.isEnabled)
        XCTAssertFalse(harness.controller.isPreventingSleep)
        XCTAssertEqual(harness.timer.pauseCount, 1)
        XCTAssertEqual(harness.assertion.releaseCount, 1)

        harness.controller.screenDidUnlock()

        XCTAssertEqual(harness.controller.state, .active(.seconds(600)))
        XCTAssertEqual(harness.timer.resumeCount, 1)
        XCTAssertEqual(harness.assertion.acquireValues, [false, false])
    }

    func testBatteryTransitionDeactivatesOnlyFromExternalPower() {
        let harness = makeHarness()
        harness.store.update { $0.keepAwakeDeactivateOnBattery = true }
        harness.controller.startDefault()

        harness.controller.powerSourceDidChange(from: .unknown, to: .battery)
        XCTAssertTrue(harness.controller.isEnabled)

        harness.controller.powerSourceDidChange(from: .external, to: .battery)
        XCTAssertEqual(harness.controller.state, .inactive)

        harness.controller.startDefault()
        harness.controller.powerSourceDidChange(from: .battery, to: .battery)
        XCTAssertTrue(harness.controller.isEnabled)
    }

    func testImprovedTimerUsesContinuousTimeInsteadOfWallClock() throws {
        var wallClock: TimeInterval = 100
        var continuousClock: TimeInterval = 200
        let timer = KeepAwakeTimer(
            wallClockNow: { wallClock },
            monotonicNow: { continuousClock }
        )

        timer.start(duration: 120, improved: true)
        wallClock += 3_600
        continuousClock += 30
        XCTAssertEqual(try XCTUnwrap(timer.remainingTime), 90, accuracy: 0.001)

        timer.start(duration: 120, improved: false)
        wallClock += 45
        continuousClock += 3_600
        XCTAssertEqual(try XCTUnwrap(timer.remainingTime), 75, accuracy: 0.001)
        timer.cancel()
    }

    func testDisplaySleepSettingReplacesLiveAssertion() {
        let harness = makeHarness()
        harness.controller.startDefault()

        harness.store.update { $0.keepAwakeAllowDisplaySleep = true }

        XCTAssertEqual(harness.assertion.acquireValues, [false, true])
        XCTAssertTrue(harness.controller.isEnabled)
    }

    func testCommandsUseConfiguredDefaultAndCustomDurations() {
        let harness = makeHarness()
        harness.store.update { $0.keepAwakeDefaultDuration = .twoHours }

        harness.controller.perform(.activate(nil))
        XCTAssertEqual(harness.controller.duration, .seconds(7_200))

        harness.controller.perform(.activate(.seconds(75)))
        XCTAssertEqual(harness.controller.duration, .seconds(75))

        harness.controller.perform(.toggle(nil))
        XCTAssertFalse(harness.controller.isEnabled)
    }

    func testAssertionFailureIsReportedWithoutDiscardingExistingSession() {
        let harness = makeHarness()
        harness.controller.startDefault()
        harness.assertion.shouldFail = true

        harness.controller.start(.seconds(60))

        XCTAssertEqual(harness.controller.state, .active(.indefinitely))
        XCTAssertNotNil(harness.controller.lastErrorMessage)
    }

    private func makeHarness() -> Harness {
        let store = SettingsStore(userDefaults: userDefaults)
        let assertion = TestPowerAssertion()
        let timer = TestKeepAwakeTimer()
        let notifier = TestCompletionNotifier()
        let controller = KeepAwakeController(
            settingsStore: store,
            powerAssertion: assertion,
            timer: timer,
            notifier: notifier
        )
        return Harness(
            store: store,
            assertion: assertion,
            timer: timer,
            notifier: notifier,
            controller: controller
        )
    }
}

private struct Harness {
    let store: SettingsStore
    let assertion: TestPowerAssertion
    let timer: TestKeepAwakeTimer
    let notifier: TestCompletionNotifier
    let controller: KeepAwakeController
}

final class TestPowerAssertion: PowerAssertionServicing {
    var isHeld = false
    var acquireValues: [Bool] = []
    var releaseCount = 0
    var shouldFail = false

    func acquire(allowDisplaySleep: Bool) throws {
        acquireValues.append(allowDisplaySleep)
        if shouldFail {
            throw TestError.failed
        }
        isHeld = true
    }

    func release() {
        guard isHeld else { return }
        isHeld = false
        releaseCount += 1
    }
}

final class TestKeepAwakeTimer: KeepAwakeTimerServicing {
    struct StartCall: Equatable {
        let duration: TimeInterval
        let improved: Bool
    }

    var remainingTime: TimeInterval?
    var isPaused = false
    var onCompletion: (() -> Void)?
    var startCalls: [StartCall] = []
    var pauseCount = 0
    var resumeCount = 0

    func start(duration: TimeInterval, improved: Bool) {
        startCalls.append(.init(duration: duration, improved: improved))
        remainingTime = duration
        isPaused = false
    }

    func pause() {
        pauseCount += 1
        isPaused = true
    }

    func resume() {
        resumeCount += 1
        isPaused = false
    }

    func cancel() {
        remainingTime = nil
        isPaused = false
    }

    func complete() {
        remainingTime = nil
        onCompletion?()
    }
}

final class TestCompletionNotifier: KeepAwakeCompletionNotifying {
    var prepareCount = 0
    var notificationCount = 0

    func prepare() {
        prepareCount += 1
    }

    func notifyCompletion() {
        notificationCount += 1
    }
}

private enum TestError: LocalizedError {
    case failed

    var errorDescription: String? { "Test assertion failure" }
}
