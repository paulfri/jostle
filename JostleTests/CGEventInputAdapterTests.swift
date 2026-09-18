import CoreGraphics
import JostleCore
import XCTest
@testable import Jostle

final class CGEventInputAdapterTests: XCTestCase {
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
