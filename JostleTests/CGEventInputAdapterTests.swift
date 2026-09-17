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
