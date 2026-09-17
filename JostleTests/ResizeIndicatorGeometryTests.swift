import JostleCore
import XCTest
@testable import Jostle

final class ResizeIndicatorGeometryTests: XCTestCase {
    func testTopLeftCornerProducesAnInwardBracket() {
        let segments = ResizeIndicatorGeometry.segments(
            for: ResizeSection(horizontalEdge: .left, verticalEdge: .top),
            in: Size(width: 600, height: 400)
        )

        XCTAssertEqual(segments, [
            ResizeIndicatorSegment(
                start: Point(x: 4, y: 396),
                end: Point(x: 40, y: 396)
            ),
            ResizeIndicatorSegment(
                start: Point(x: 4, y: 396),
                end: Point(x: 4, y: 360)
            )
        ])
    }

    func testRightEdgeProducesOneCenteredSegment() {
        XCTAssertEqual(
            ResizeIndicatorGeometry.segments(
                for: ResizeSection(horizontalEdge: .right, verticalEdge: .none),
                in: Size(width: 600, height: 400)
            ),
            [ResizeIndicatorSegment(
                start: Point(x: 596, y: 182),
                end: Point(x: 596, y: 218)
            )]
        )
    }

    func testCenterSectionProducesNoFeedback() {
        XCTAssertEqual(
            ResizeIndicatorGeometry.segments(
                for: .none,
                in: Size(width: 600, height: 400)
            ),
            []
        )
    }
}
