import XCTest
@testable import JostleCore

final class SnapPolicyTests: XCTestCase {
    private let screen = Frame(x: 100, y: 50, width: 1200, height: 800)

    func testEdgesAndCornersSelectExpectedTargets() {
        let cases: [(Point, SnapTarget?)] = [
            (Point(x: 100, y: 50), .topLeftQuarter),
            (Point(x: 700, y: 50), .maximize),
            (Point(x: 1300, y: 50), .topRightQuarter),
            (Point(x: 100, y: 450), .leftHalf),
            (Point(x: 1300, y: 450), .rightHalf),
            (Point(x: 100, y: 850), .bottomLeftQuarter),
            (Point(x: 1300, y: 850), .bottomRightQuarter),
            (Point(x: 700, y: 850), nil),
            (Point(x: 700, y: 450), nil)
        ]

        for (point, expected) in cases {
            XCTAssertEqual(
                SnapPolicy.target(for: point, in: screen, activationDistance: 12),
                expected,
                "point: \(point)"
            )
        }
    }

    func testActivationDistanceIncludesPointsNearAnEdge() {
        XCTAssertEqual(
            SnapPolicy.target(
                for: Point(x: 111, y: 450),
                in: screen,
                activationDistance: 12
            ),
            .leftHalf
        )
        XCTAssertNil(
            SnapPolicy.target(
                for: Point(x: 113, y: 450),
                in: screen,
                activationDistance: 12
            )
        )
    }

    func testResizeRegionsMapToDoubleClickSnapTargets() {
        XCTAssertEqual(
            SnapPolicy.target(
                for: ResizeSection(horizontalEdge: .left, verticalEdge: .top)
            ),
            .topLeftQuarter
        )
        XCTAssertEqual(
            SnapPolicy.target(
                for: ResizeSection(horizontalEdge: .none, verticalEdge: .top)
            ),
            .topHalf
        )
        XCTAssertEqual(
            SnapPolicy.target(
                for: ResizeSection(horizontalEdge: .none, verticalEdge: .bottom)
            ),
            .bottomHalf
        )
        XCTAssertEqual(SnapPolicy.target(for: .none), .maximize)
    }

    func testFramesApplyOuterMarginAndInteriorGap() {
        let visibleFrame = Frame(x: 0, y: 20, width: 1000, height: 700)

        XCTAssertEqual(
            SnapPolicy.frame(
                for: .leftHalf,
                in: visibleFrame,
                gap: 12,
                screenMargin: 8
            ),
            Frame(x: 8, y: 28, width: 486, height: 684)
        )
        XCTAssertEqual(
            SnapPolicy.frame(
                for: .topHalf,
                in: visibleFrame,
                gap: 12,
                screenMargin: 8
            ),
            Frame(x: 8, y: 28, width: 984, height: 336)
        )
        XCTAssertEqual(
            SnapPolicy.frame(
                for: .bottomRightQuarter,
                in: visibleFrame,
                gap: 12,
                screenMargin: 8
            ),
            Frame(x: 506, y: 376, width: 486, height: 336)
        )
        XCTAssertEqual(
            SnapPolicy.frame(
                for: .maximize,
                in: visibleFrame,
                gap: 12,
                screenMargin: 8
            ),
            Frame(x: 8, y: 28, width: 984, height: 684)
        )
    }

    func testNegativeSpacingValuesAreClampedToZero() {
        XCTAssertEqual(
            SnapPolicy.frame(
                for: .topLeftQuarter,
                in: Frame(x: 0, y: 0, width: 1000, height: 800),
                gap: -10,
                screenMargin: -20
            ),
            Frame(x: 0, y: 0, width: 500, height: 400)
        )
    }
}
