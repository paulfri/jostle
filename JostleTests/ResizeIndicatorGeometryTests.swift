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
                start: Point(x: 16, y: 392),
                end: Point(x: 52, y: 392)
            ),
            ResizeIndicatorSegment(
                start: Point(x: 8, y: 384),
                end: Point(x: 8, y: 348)
            )
        ])
        XCTAssertNotEqual(segments[0].start, segments[1].start)
    }

    func testRightEdgeProducesOneCenteredSegment() {
        XCTAssertEqual(
            ResizeIndicatorGeometry.segments(
                for: ResizeSection(horizontalEdge: .right, verticalEdge: .none),
                in: Size(width: 600, height: 400)
            ),
            [ResizeIndicatorSegment(
                start: Point(x: 592, y: 182),
                end: Point(x: 592, y: 218)
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
