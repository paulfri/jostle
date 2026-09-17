import XCTest
@testable import JostleCore

final class EventPolicyTests: XCTestCase {
    private let requiredModifiers: Set<Modifier> = [.control, .command]

    private func configuration(
        sessionActive: Bool = true,
        gestureActive: Bool = false,
        middleClickResize: Bool = false,
        resizeOnly: Bool = false,
        doubleClickActionsEnabled: Bool = true,
        ownedActionButton: MouseButton? = nil
    ) -> EventPolicyConfiguration {
        EventPolicyConfiguration(
            sessionActive: sessionActive,
            gestureActive: gestureActive,
            middleClickResize: middleClickResize,
            resizeOnly: resizeOnly,
            requiredModifiers: requiredModifiers,
            doubleClickActionsEnabled: doubleClickActionsEnabled,
            ownedActionButton: ownedActionButton
        )
    }

    func testExactModifiersBeginMove() {
        let event = InputEvent(type: .mouseDown, button: .left, modifiers: requiredModifiers)
        XCTAssertEqual(EventPolicy.intent(for: event, configuration: configuration()), .beginMove)
    }

    func testMissingOrExtraModifiersPassThrough() {
        let missing = InputEvent(type: .mouseDown, button: .left, modifiers: [.control])
        let extra = InputEvent(type: .mouseDown, button: .left, modifiers: [.control, .command, .shift])

        XCTAssertEqual(EventPolicy.intent(for: missing, configuration: configuration()), .passThrough)
        XCTAssertEqual(EventPolicy.intent(for: extra, configuration: configuration()), .passThrough)
    }

    func testResizeButtonAndResizeOnlyRouting() {
        let middleDown = InputEvent(type: .mouseDown, button: .other, modifiers: requiredModifiers)
        XCTAssertEqual(
            EventPolicy.intent(for: middleDown, configuration: configuration(middleClickResize: true)),
            .beginResize
        )

        let leftDown = InputEvent(type: .mouseDown, button: .left, modifiers: requiredModifiers)
        XCTAssertEqual(
            EventPolicy.intent(for: leftDown, configuration: configuration(resizeOnly: true)),
            .passThrough
        )
    }

    func testDoubleClicksRouteToConfiguredActions() {
        let leftDoubleClick = InputEvent(
            type: .mouseDown,
            button: .left,
            modifiers: requiredModifiers,
            clickCount: 2
        )
        let rightDoubleClick = InputEvent(
            type: .mouseDown,
            button: .right,
            modifiers: requiredModifiers,
            clickCount: 2
        )

        XCTAssertEqual(
            EventPolicy.intent(for: leftDoubleClick, configuration: configuration()),
            .toggleMaximize
        )
        XCTAssertEqual(
            EventPolicy.intent(for: rightDoubleClick, configuration: configuration()),
            .snapByRegion
        )
        XCTAssertEqual(
            EventPolicy.intent(
                for: leftDoubleClick,
                configuration: configuration(doubleClickActionsEnabled: false)
            ),
            .beginMove
        )
    }

    func testEscapeCancelsAnActiveGestureWithoutModifiersOrSession() {
        let escape = InputEvent(
            type: .keyDown,
            button: .none,
            modifiers: [],
            keyCode: 53
        )

        XCTAssertEqual(
            EventPolicy.intent(
                for: escape,
                configuration: configuration(sessionActive: false, gestureActive: true)
            ),
            .cancelGesture
        )
        XCTAssertEqual(
            EventPolicy.intent(for: escape, configuration: configuration()),
            .passThrough
        )
    }

    func testOwnedActionMouseUpIsConsumedWithoutModifiers() {
        let mouseUp = InputEvent(type: .mouseUp, button: .right, modifiers: [])

        XCTAssertEqual(
            EventPolicy.intent(
                for: mouseUp,
                configuration: configuration(
                    sessionActive: false,
                    ownedActionButton: .right
                )
            ),
            .endActionClick
        )
    }

    func testOwnedMouseUpEndsAfterModifiersOrSessionAreLost() {
        let mouseUp = InputEvent(type: .mouseUp, button: .left, modifiers: [])
        XCTAssertEqual(
            EventPolicy.intent(
                for: mouseUp,
                configuration: configuration(sessionActive: false, gestureActive: true)
            ),
            .endGesture
        )
    }

    func testTapRecoveryDoesNotDependOnCurrentSettings() {
        let disabled = InputEvent(type: .tapDisabledByTimeout, button: .none, modifiers: [])
        var inactiveConfiguration = configuration(sessionActive: false)
        inactiveConfiguration.requiredModifiers = []

        XCTAssertEqual(
            EventPolicy.intent(for: disabled, configuration: inactiveConfiguration),
            .reenableEventTap
        )
    }
}
