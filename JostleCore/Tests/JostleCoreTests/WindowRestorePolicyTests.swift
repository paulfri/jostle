import XCTest
@testable import JostleCore

final class WindowRestorePolicyTests: XCTestCase {
    func testRestoredSizeKeepsPointerAtSameRelativeLocation() {
        let result = WindowRestorePolicy.restoredFrame(
            savedFrame: Frame(x: 300, y: 200, width: 800, height: 600),
            currentFrame: Frame(x: 0, y: 20, width: 500, height: 800),
            grabbedAt: Point(x: 125, y: 220)
        )

        XCTAssertEqual(result, Frame(x: -75, y: 70, width: 800, height: 600))
    }

    func testGrabFractionsAreClampedToWindowBounds() {
        XCTAssertEqual(
            WindowRestorePolicy.restoredFrame(
                savedFrame: Frame(x: 0, y: 0, width: 600, height: 400),
                currentFrame: Frame(x: 100, y: 100, width: 300, height: 200),
                grabbedAt: Point(x: 50, y: 350)
            ),
            Frame(x: 50, y: -50, width: 600, height: 400)
        )
    }

    func testInvalidCurrentSizeCentersRestoredWindowOnPointer() {
        XCTAssertEqual(
            WindowRestorePolicy.restoredFrame(
                savedFrame: Frame(x: 0, y: 0, width: 600, height: 400),
                currentFrame: Frame(x: 10, y: 20, width: 0, height: 0),
                grabbedAt: Point(x: 500, y: 400)
            ),
            Frame(x: 200, y: 200, width: 600, height: 400)
        )
    }
}
