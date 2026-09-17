import JostleCore
import XCTest
@testable import Jostle

final class AccessibilityWindowSystemTests: XCTestCase {
    func testRequestedSizesAreClampedAtAdapterBoundary() {
        XCTAssertEqual(
            AccessibilityWindowSystem.constrainedSize(
                Size(width: 40, height: 20),
                minimumSize: Size(width: 320, height: 200)
            ),
            Size(width: 320, height: 200)
        )
        XCTAssertEqual(
            AccessibilityWindowSystem.constrainedSize(
                Size(width: 900, height: 700),
                minimumSize: Size(width: 320, height: 200)
            ),
            Size(width: 900, height: 700)
        )
    }

    func testSettingAFrameMovesBeforeAndAfterResizing() {
        let frame = Frame(x: 100, y: 25, width: 900, height: 700)

        XCTAssertEqual(
            AccessibilityWindowSystem.frameCommands(for: frame),
            [
                .setPosition(Point(x: 100, y: 25)),
                .setSize(Size(width: 900, height: 700)),
                .setPosition(Point(x: 100, y: 25))
            ]
        )
    }
}
