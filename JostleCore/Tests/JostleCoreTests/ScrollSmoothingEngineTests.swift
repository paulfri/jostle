// Adapted from LinearMouse SmoothedScrollingEngineTests.swift.
// MIT License
// Copyright (c) 2021-2026 LinearMouse

import XCTest
@testable import JostleCore

final class ScrollSmoothingEngineTests: XCTestCase {
    private let smoothing = EffectiveScrollSmoothingSettings(
        preset: .easeInOut,
        response: 0.68,
        speed: 1.02,
        acceleration: 1.1,
        inertia: 0.74,
        bouncing: true
    )

    func testTransitionsFromTouchIntoMomentumAndEnds() {
        let engine = ScrollSmoothingEngine(horizontal: nil, vertical: smoothing)
        var phases: [ScrollSmoothingEngine.Phase] = []

        for step in 0 ..< 6 {
            let timestamp = Double(step) / 120
            engine.feed(deltaX: 0, deltaY: 40, timestamp: timestamp)
            if let emission = engine.advance(to: timestamp + 1.0 / 120) {
                phases.append(emission.phase)
            }
        }
        for step in 6 ..< 480 {
            if let emission = engine.advance(to: Double(step + 1) / 120) {
                phases.append(emission.phase)
            }
        }

        XCTAssertEqual(phases.first, .touchBegan)
        XCTAssertTrue(phases.contains(.touchChanged))
        XCTAssertTrue(phases.contains(.touchEnded))
        XCTAssertTrue(phases.contains(.momentumBegan))
        XCTAssertTrue(phases.contains(.momentumChanged))
        XCTAssertEqual(phases.last, .momentumEnded)
    }

    func testUnsmoothedAxisPassesThrough() throws {
        let engine = ScrollSmoothingEngine(horizontal: nil, vertical: smoothing)
        engine.feed(deltaX: 18, deltaY: 24, timestamp: 0)

        let emission = try XCTUnwrap(engine.advance(to: 1.0 / 120))

        XCTAssertEqual(emission.phase, .touchBegan)
        XCTAssertEqual(emission.deltaX, 18, accuracy: 0.001)
        XCTAssertGreaterThan(abs(emission.deltaY), 0)
    }

    func testZeroInertiaEndsWithoutMomentumTail() {
        var noInertia = smoothing
        noInertia.inertia = 0
        let engine = ScrollSmoothingEngine(horizontal: nil, vertical: noInertia)
        engine.feed(deltaX: 0, deltaY: 36, timestamp: 0)
        _ = engine.advance(to: 1.0 / 120)

        var phases: [ScrollSmoothingEngine.Phase] = []
        for step in 2 ..< 40 {
            if let emission = engine.advance(to: Double(step) / 120) {
                phases.append(emission.phase)
            }
        }

        XCTAssertFalse(phases.contains(.momentumBegan))
        XCTAssertFalse(engine.isRunning)
    }
}
