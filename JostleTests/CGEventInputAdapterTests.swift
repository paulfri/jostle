import CoreGraphics
import JostleCore
import XCTest
@testable import Jostle

final class CGEventInputAdapterTests: XCTestCase {
    func testRuntimeDiagnosticsUsesBoundedHistogramsAndCountsTapRecovery() {
        let diagnostics = InputRuntimeDiagnostics()
        diagnostics.recordEventTap(durationNanoseconds: 100_000, type: .mouseMoved)
        diagnostics.recordEventTap(durationNanoseconds: 200_000, type: .tapDisabledByTimeout)
        diagnostics.recordEventTap(
            durationNanoseconds: 5_000_000,
            type: .tapDisabledByUserInput,
            isJostleSynthetic: true
        )
        diagnostics.recordSmoothingTick(durationNanoseconds: 80_000)

        let snapshot = diagnostics.snapshot()
        XCTAssertEqual(snapshot.eventTap.sampleCount, 3)
        XCTAssertEqual(snapshot.eventTap.averageMicroseconds, 1_766.666, accuracy: 0.01)
        XCTAssertEqual(snapshot.eventTap.p95Microseconds, 5_000)
        XCTAssertEqual(snapshot.eventTap.p99Microseconds, 5_000)
        XCTAssertEqual(snapshot.eventTap.maximumMicroseconds, 5_000)
        XCTAssertEqual(snapshot.smoothingTick.sampleCount, 1)
        XCTAssertEqual(snapshot.smoothingTick.p95Microseconds, 100)
        XCTAssertEqual(snapshot.tapDisabledByTimeoutCount, 1)
        XCTAssertEqual(snapshot.tapDisabledByUserInputCount, 1)
        XCTAssertEqual(snapshot.jostleSyntheticEventCount, 1)
    }

    func testInputUtilityConflictDetectorUsesKnownBundleIDsAndNames() {
        let conflicts = InputUtilityConflictDetector.conflicts(
            applications: [
                RunningApplicationIdentity(
                    bundleIdentifier: "com.lujjjh.LinearMouse",
                    localizedName: "Renamed Utility"
                ),
                RunningApplicationIdentity(
                    bundleIdentifier: "com.example.unrelated",
                    localizedName: "Mac Mouse Fix Helper"
                ),
                RunningApplicationIdentity(
                    bundleIdentifier: "fm.pau.jostle.development",
                    localizedName: "LinearMouse"
                ),
                RunningApplicationIdentity(
                    bundleIdentifier: "com.example.cosmos",
                    localizedName: "Cosmos"
                ),
            ],
            currentBundleIdentifier: "fm.pau.jostle.development"
        )

        XCTAssertEqual(conflicts, ["LinearMouse", "Mac Mouse Fix"])
    }

    func testDiagnosticsReportRedactsApplicationAndDeviceIdentity() {
        var settings = JostleSettings.defaults
        settings.applicationRules["com.private.customer"] = ApplicationRule(
            displayName: "Private Customer App",
            commandKeyRecovery: true
        )
        settings.inputCustomization.deviceRules["serial-private-123"] = PointingDeviceRule(
            displayName: "Private Mouse Name",
            category: .mouse
        )
        let runtime = InputRuntimeDiagnosticsSnapshot(
            eventTap: RuntimeTimingSummary(
                sampleCount: 10,
                averageMicroseconds: 20,
                p95Microseconds: 50,
                p99Microseconds: 100,
                maximumMicroseconds: 90
            ),
            smoothingTick: RuntimeTimingSummary(
                sampleCount: 5,
                averageMicroseconds: 10,
                p95Microseconds: 25,
                p99Microseconds: 25,
                maximumMicroseconds: 22
            ),
            tapDisabledByTimeoutCount: 1,
            tapDisabledByUserInputCount: 0,
            jostleSyntheticEventCount: 4
        )

        let report = InputDiagnosticsReport.make(
            settings: settings,
            runtime: runtime,
            context: InputDiagnosticsReportContext(
                eventTapRequested: true,
                eventTapOperational: true,
                inputCustomizationsEnabled: false,
                safeMode: false,
                sessionActive: true,
                accessibilityTrusted: true,
                connectedDeviceCounts: [.mouse: 1],
                conflictingUtilities: ["LinearMouse"]
            ),
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(report.contains("application_override_count: 1"))
        XCTAssertTrue(report.contains("command_key_recovery_rules: 1"))
        XCTAssertTrue(report.contains("exact_mouse_rules: 1"))
        XCTAssertTrue(report.contains("callback_samples: 10"))
        XCTAssertTrue(report.contains("known_input_utility_conflicts: LinearMouse"))
        XCTAssertFalse(report.contains("com.private.customer"))
        XCTAssertFalse(report.contains("Private Customer App"))
        XCTAssertFalse(report.contains("serial-private-123"))
        XCTAssertFalse(report.contains("Private Mouse Name"))
    }

    func testMapsEveryObservedMouseEvent() {
        let cases: [(CGEventType, InputEventType, MouseButton)] = [
            (.leftMouseDown, .mouseDown, .left),
            (.rightMouseDown, .mouseDown, .right),
            (.otherMouseDown, .mouseDown, .other),
            (.leftMouseDragged, .mouseDragged, .left),
            (.rightMouseDragged, .mouseDragged, .right),
            (.otherMouseDragged, .mouseDragged, .other),
            (.leftMouseUp, .mouseUp, .left),
            (.rightMouseUp, .mouseUp, .right),
            (.otherMouseUp, .mouseUp, .other),
            (.keyDown, .keyDown, .none),
            (.tapDisabledByTimeout, .tapDisabledByTimeout, .none),
            (.tapDisabledByUserInput, .tapDisabledByUserInput, .none)
        ]

        for (type, expectedType, expectedButton) in cases {
            let input = CGEventInputAdapter.input(type: type, flags: [])
            XCTAssertEqual(input.type, expectedType)
            XCTAssertEqual(input.button, expectedButton)
        }
    }

    func testPreservesKeyboardKeyCode() {
        XCTAssertEqual(
            CGEventInputAdapter.input(
                type: .keyDown,
                flags: [],
                keyCode: 53
            ).keyCode,
            53
        )
    }

    func testPreservesMouseClickCount() {
        XCTAssertEqual(
            CGEventInputAdapter.input(
                type: .leftMouseDown,
                flags: [],
                clickCount: 2
            ).clickCount,
            2
        )
    }

    func testPreservesPhysicalMouseButtonNumber() {
        XCTAssertEqual(
            CGEventInputAdapter.input(
                type: .otherMouseDown,
                flags: [],
                mouseButtonNumber: 4
            ).buttonNumber,
            4
        )
    }

    func testReverseScrollNegatesIntegerFixedAndPointDeltas() throws {
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 8,
            wheel2: -3,
            wheel3: 0
        ))
        let fields: [CGEventField] = [
            .scrollWheelEventDeltaAxis1,
            .scrollWheelEventDeltaAxis2,
            .scrollWheelEventFixedPtDeltaAxis1,
            .scrollWheelEventFixedPtDeltaAxis2,
            .scrollWheelEventPointDeltaAxis1,
            .scrollWheelEventPointDeltaAxis2,
        ]
        let originalValues = fields.map(event.getDoubleValueField)

        CGEventScrollAdapter.reverse(event)

        for (field, originalValue) in zip(fields, originalValues) {
            XCTAssertEqual(event.getDoubleValueField(field), -originalValue, accuracy: 0.0001)
        }
    }

    func testScrollCustomizationAppliesResolvedReverseAndDistance() throws {
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 1,
            wheel2: 0,
            wheel3: 0
        ))
        let controller = ScrollCustomizationController()
        let axis = EffectiveScrollAxisSettings(
            reverse: true,
            distance: .lines(3),
            acceleration: 1,
            speed: 0,
            smoothing: nil
        )
        let settings = EffectiveScrollSettings(
            horizontal: .passthrough,
            vertical: axis
        )

        XCTAssertFalse(controller.handle(event, settings: settings))
        XCTAssertEqual(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1), -3, accuracy: 0.001)
        XCTAssertEqual(event.getIntegerValueField(.scrollWheelEventIsContinuous), 0)
    }

    func testScrollCustomizationSuppressesHandledSmoothedAxis() throws {
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 1,
            wheel2: 0,
            wheel3: 0
        ))
        let controller = ScrollCustomizationController()
        defer { controller.cancel() }
        let smoothing = EffectiveScrollSmoothingSettings(
            preset: .easeInOut,
            response: 0.68,
            speed: 1.02,
            acceleration: 1.1,
            inertia: 0.74,
            bouncing: true
        )
        var vertical = EffectiveScrollAxisSettings.passthrough
        vertical.smoothing = smoothing

        XCTAssertTrue(controller.handle(
            event,
            settings: EffectiveScrollSettings(
                horizontal: .passthrough,
                vertical: vertical
            )
        ))
        XCTAssertEqual(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1), 0, accuracy: 0.001)
    }

    func testSmoothedScrollEmissionDoesNotReuseStaleSourceLocation() throws {
        let sourceLocation = CGPoint(x: 1, y: 1)
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: 1,
            wheel2: 0,
            wheel3: 0
        ))
        event.location = sourceLocation
        var emittedLocation: CGPoint?
        let controller = ScrollCustomizationController { emittedLocation = $0.location }
        defer { controller.cancel() }
        let smoothing = EffectiveScrollSmoothingSettings(
            preset: .easeInOut,
            response: 0.68,
            speed: 1.02,
            acceleration: 1.1,
            inertia: 0.74,
            bouncing: true
        )
        var vertical = EffectiveScrollAxisSettings.passthrough
        vertical.smoothing = smoothing

        XCTAssertTrue(controller.handle(
            event,
            settings: EffectiveScrollSettings(
                horizontal: .passthrough,
                vertical: vertical
            )
        ))
        controller.tick()

        XCTAssertNotNil(emittedLocation)
        XCTAssertNotEqual(emittedLocation, sourceLocation)
    }

    func testPointingDeviceClassifierRejectsKeyboardPrimaryCompositeDevices() {
        XCTAssertNil(PointingDeviceClassifier.category(
            primaryUsagePage: 1,
            primaryUsage: 6,
            conformsToTouchpad: false
        ))
    }

    func testPointingDeviceClassifierAcceptsMousePointerAndTrackpadDevices() {
        XCTAssertEqual(PointingDeviceClassifier.category(
            primaryUsagePage: 1,
            primaryUsage: 2,
            conformsToTouchpad: false
        ), .mouse)
        XCTAssertEqual(PointingDeviceClassifier.category(
            primaryUsagePage: 1,
            primaryUsage: 1,
            conformsToTouchpad: false
        ), .mouse)
        XCTAssertEqual(PointingDeviceClassifier.category(
            primaryUsagePage: 13,
            primaryUsage: 5,
            conformsToTouchpad: true
        ), .trackpad)
    }

    func testSafeModeSuppressesInputCustomizationIntent() {
        let defaults = UserDefaults(suiteName: "CGEventInputAdapterTests.safe-mode")!
        defaults.removePersistentDomain(forName: "CGEventInputAdapterTests.safe-mode")
        let store = SettingsStore(userDefaults: defaults)
        store.update { $0.inputCustomization.isEnabled = true }
        let controller = EventTapController(
            settingsStore: store,
            safeMode: true,
            gestureConfiguration: GestureConfiguration(
                moveThrottleInterval: 1,
                resizeThrottleInterval: 1
            )
        )

        XCTAssertTrue(controller.isInSafeMode)
        XCTAssertFalse(controller.inputCustomizationsRequested)
    }

    func testMapsOnlySupportedModifierFlags() {
        let flags: CGEventFlags = [
            .maskControl,
            .maskAlternate,
            .maskShift,
            .maskCommand,
            .maskAlphaShift,
            .maskSecondaryFn,
            .maskNumericPad
        ]

        XCTAssertEqual(
            CGEventInputAdapter.modifiers(from: flags),
            [.control, .option, .shift, .command, .capsLock, .function]
        )
    }
}
