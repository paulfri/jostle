import XCTest
@testable import JostleCore

final class GestureEngineTests: XCTestCase {
    private let configuration = GestureConfiguration(
        moveThrottleInterval: 10,
        resizeThrottleInterval: 10
    )
    private let frame = Frame(x: 100, y: 200, width: 600, height: 300)

    func testMoveUsesStrictThrottleBoundary() {
        let moving = GestureEngine.reduce(
            state: .idle,
            input: .beginMove(frame: frame, timestamp: 100),
            configuration: configuration
        ).state
        let atBoundary = GestureEngine.reduce(
            state: moving,
            input: .moveBy(deltaX: 2, deltaY: 3, timestamp: 110),
            configuration: configuration
        )

        XCTAssertEqual(atBoundary.commands, [])
        XCTAssertEqual(
            atBoundary.state,
            .moving(GestureContext(
                frame: Frame(x: 102, y: 203, width: 600, height: 300),
                resizeSection: .none,
                lastWriteTime: 100,
                geometryDirty: true
            ))
        )

        let aboveBoundary = GestureEngine.reduce(
            state: atBoundary.state,
            input: .moveBy(deltaX: 4, deltaY: -1, timestamp: 111),
            configuration: configuration
        )
        XCTAssertEqual(aboveBoundary.commands, [.setPosition(Point(x: 106, y: 202))])
    }

    func testMoveEndFlushesPendingGeometry() {
        let moving = GestureEngine.reduce(
            state: .idle,
            input: .beginMove(frame: frame, timestamp: 100),
            configuration: configuration
        ).state
        let pending = GestureEngine.reduce(
            state: moving,
            input: .moveBy(deltaX: 4, deltaY: 3, timestamp: 105),
            configuration: configuration
        ).state
        let ended = GestureEngine.reduce(
            state: pending,
            input: .end(timestamp: 106),
            configuration: configuration
        )

        XCTAssertEqual(ended.state, .idle)
        XCTAssertEqual(ended.commands, [.setPosition(Point(x: 104, y: 203))])
    }

    func testLeadingEdgeResizeWritesPositionBeforeSizeOnEnd() {
        let section = ResizeSection(horizontalEdge: .left, verticalEdge: .top)
        let resizing = GestureEngine.reduce(
            state: .idle,
            input: .beginResize(frame: frame, section: section, timestamp: 100),
            configuration: configuration
        ).state
        let pending = GestureEngine.reduce(
            state: resizing,
            input: .resizeBy(deltaX: -10, deltaY: -8, timestamp: 105),
            configuration: configuration
        ).state
        let ended = GestureEngine.reduce(
            state: pending,
            input: .end(timestamp: 106),
            configuration: configuration
        )

        XCTAssertEqual(ended.state, .idle)
        XCTAssertEqual(ended.commands, [
            .setPosition(Point(x: 90, y: 192)),
            .setSize(Size(width: 610, height: 308))
        ])
    }

    func testResizeUsesConfiguredMinimumWindowSize() {
        let resizing = GestureEngine.reduce(
            state: .idle,
            input: .beginResize(
                frame: Frame(x: 0, y: 0, width: 200, height: 200),
                section: ResizeSection(horizontalEdge: .right, verticalEdge: .none),
                timestamp: 100
            ),
            configuration: configuration
        ).state
        let resized = GestureEngine.reduce(
            state: resizing,
            input: .resizeBy(deltaX: -500, deltaY: 0, timestamp: 111),
            configuration: configuration
        )

        XCTAssertEqual(resized.commands, [.setSize(Size(width: 160, height: 200))])
        XCTAssertEqual(resized.state.context?.frame, Frame(x: 0, y: 0, width: 160, height: 200))
    }

    func testSynchronizeFrameAdoptsApplicationConstraints() {
        let section = ResizeSection(horizontalEdge: .right, verticalEdge: .bottom)
        let resizing = GestureEngine.reduce(
            state: .idle,
            input: .beginResize(frame: frame, section: section, timestamp: 100),
            configuration: configuration
        ).state
        let synchronized = GestureEngine.reduce(
            state: resizing,
            input: .synchronizeFrame(Frame(x: 100, y: 200, width: 480, height: 240)),
            configuration: configuration
        )

        XCTAssertEqual(synchronized.commands, [])
        XCTAssertEqual(
            synchronized.state,
            .resizing(GestureContext(
                frame: Frame(x: 100, y: 200, width: 480, height: 240),
                resizeSection: section,
                lastWriteTime: 100,
                geometryDirty: false
            ))
        )
    }

    func testCancelDropsPendingGeometry() {
        let moving = GestureEngine.reduce(
            state: .idle,
            input: .beginMove(frame: frame, timestamp: 100),
            configuration: configuration
        ).state
        let pending = GestureEngine.reduce(
            state: moving,
            input: .moveBy(deltaX: 4, deltaY: 3, timestamp: 105),
            configuration: configuration
        ).state
        let cancelled = GestureEngine.reduce(
            state: pending,
            input: .cancel(timestamp: 106),
            configuration: configuration
        )

        XCTAssertEqual(cancelled, GestureTransition(state: .idle, commands: []))
    }
}
