import XCTest
@testable import JostleCore

final class GeometryTests: XCTestCase {
    func testAllNineResizeRegionsUsePhysicalEdges() {
        let frame = Frame(x: 100, y: 200, width: 300, height: 300)
        let cases: [(Point, ResizeSection)] = [
            (Point(x: 150, y: 250), ResizeSection(horizontalEdge: .left, verticalEdge: .top)),
            (Point(x: 250, y: 250), ResizeSection(horizontalEdge: .none, verticalEdge: .top)),
            (Point(x: 350, y: 250), ResizeSection(horizontalEdge: .right, verticalEdge: .top)),
            (Point(x: 150, y: 350), ResizeSection(horizontalEdge: .left, verticalEdge: .none)),
            (Point(x: 250, y: 350), .none),
            (Point(x: 350, y: 350), ResizeSection(horizontalEdge: .right, verticalEdge: .none)),
            (Point(x: 150, y: 450), ResizeSection(horizontalEdge: .left, verticalEdge: .bottom)),
            (Point(x: 250, y: 450), ResizeSection(horizontalEdge: .none, verticalEdge: .bottom)),
            (Point(x: 350, y: 450), ResizeSection(horizontalEdge: .right, verticalEdge: .bottom))
        ]

        for (point, expected) in cases {
            XCTAssertEqual(GeometryPolicy.resizeSection(for: point, in: frame), expected, "point: \(point)")
        }
    }

    func testThirdBoundariesBelongToMiddleRegion() {
        let frame = Frame(x: 0, y: 0, width: 300, height: 300)
        XCTAssertEqual(
            GeometryPolicy.resizeSection(for: Point(x: 100, y: 100), in: frame),
            .none
        )
        XCTAssertEqual(
            GeometryPolicy.resizeSection(for: Point(x: 200, y: 200), in: frame),
            .none
        )
    }

    func testMovePreservesFractionalDeltas() {
        XCTAssertEqual(
            GeometryPolicy.move(Point(x: 10.25, y: 20.75), deltaX: 0.5, deltaY: -1.25),
            Point(x: 10.75, y: 19.5)
        )
    }

    func testTopLeftResizeTruncatesEachDeltaAndPreservesOppositeEdges() {
        let frame = Frame(x: 100, y: 200, width: 600, height: 300)
        let section = ResizeSection(horizontalEdge: .left, verticalEdge: .top)
        let result = GeometryPolicy.resize(
            frame,
            section: section,
            deltaX: -20.9,
            deltaY: -10.9
        )

        XCTAssertEqual(result, Frame(x: 80, y: 190, width: 620, height: 310))
        XCTAssertEqual(result.origin.x + result.size.width, frame.origin.x + frame.size.width)
        XCTAssertEqual(result.origin.y + result.size.height, frame.origin.y + frame.size.height)
    }
}
