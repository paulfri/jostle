import XCTest
@testable import Jostle

final class RuntimeHealthTests: XCTestCase {
    func testAccessibilityAlwaysTakesPriority() {
        XCTAssertEqual(
            RuntimeHealthPolicy.availability(
                accessibilityTrusted: false,
                eventTapRequested: true,
                eventTapOperational: false
            ),
            .accessibilityRequired
        )
    }

    func testRequestedEventTapMustBeOperational() {
        XCTAssertEqual(
            RuntimeHealthPolicy.availability(
                accessibilityTrusted: true,
                eventTapRequested: true,
                eventTapOperational: false
            ),
            .eventTapUnavailable
        )
        XCTAssertEqual(
            RuntimeHealthPolicy.availability(
                accessibilityTrusted: true,
                eventTapRequested: true,
                eventTapOperational: true
            ),
            .ready
        )
    }

    func testIntentionalDisableRemainsHealthyWithoutAnEventTap() {
        XCTAssertEqual(
            RuntimeHealthPolicy.availability(
                accessibilityTrusted: true,
                eventTapRequested: false,
                eventTapOperational: false
            ),
            .ready
        )
    }
}
