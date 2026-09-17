import AppKit
import JostleCore
import XCTest
@testable import Jostle

final class ScreenGeometryTests: XCTestCase {
    func testCocoaToAccessibilityCoordinatesUseTopLeftOrigin() {
        XCTAssertEqual(
            ScreenGeometryProvider.accessibilityFrame(
                from: NSRect(x: 0, y: 0, width: 1920, height: 1055),
                primaryMaximumY: 1080
            ),
            Frame(x: 0, y: 25, width: 1920, height: 1055)
        )
        XCTAssertEqual(
            ScreenGeometryProvider.accessibilityFrame(
                from: NSRect(x: 1920, y: 180, width: 1440, height: 900),
                primaryMaximumY: 1080
            ),
            Frame(x: 1920, y: 0, width: 1440, height: 900)
        )
    }

    func testAccessibilityFrameRoundTripsToCocoaCoordinates() {
        let accessibilityFrame = Frame(x: -1280, y: -100, width: 1280, height: 800)
        let cocoaFrame = ScreenGeometryProvider.cocoaFrame(
            from: accessibilityFrame,
            primaryMaximumY: 1080
        )

        XCTAssertEqual(cocoaFrame, NSRect(x: -1280, y: 380, width: 1280, height: 800))
        XCTAssertEqual(
            ScreenGeometryProvider.accessibilityFrame(
                from: cocoaFrame,
                primaryMaximumY: 1080
            ),
            accessibilityFrame
        )
    }
}
