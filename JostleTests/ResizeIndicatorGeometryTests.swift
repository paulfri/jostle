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
                start: Point(x: 12, y: 388),
                end: Point(x: 48, y: 388)
            ),
            ResizeIndicatorSegment(
                start: Point(x: 12, y: 388),
                end: Point(x: 12, y: 352)
            )
        ])
        XCTAssertEqual(segments[0].start, segments[1].start)
    }

    func testRightEdgeProducesOneCenteredSegment() {
        XCTAssertEqual(
            ResizeIndicatorGeometry.segments(
                for: ResizeSection(horizontalEdge: .right, verticalEdge: .none),
                in: Size(width: 600, height: 400)
            ),
            [ResizeIndicatorSegment(
                start: Point(x: 588, y: 182),
                end: Point(x: 588, y: 218)
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
