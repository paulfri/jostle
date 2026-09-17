import JostleCore
import XCTest
@testable import Jostle

final class AccessibilityWindowSystemTests: XCTestCase {
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
