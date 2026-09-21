import Dispatch
import XCTest
@testable import JostleCore

/// Broad regression guards for the pure transformation work that runs inside
/// the event-tap path. Runtime diagnostics capture end-to-end callback timing.
final class InputPerformanceBaselineTests: XCTestCase {
    func testEventPolicyBaseline() {
        let configuration = EventPolicyConfiguration(
            sessionActive: true,
            gestureActive: false,
            middleClickResize: false,
            resizeOnly: false,
            requiredModifiers: [.control, .command],
            doubleClickActionsEnabled: true,
            ownedActionButton: nil
        )
        let event = InputEvent(
            type: .mouseDown,
            button: .left,
            modifiers: [.control, .command]
        )
        let iterations = 100_000

        let startedAt = DispatchTime.now().uptimeNanoseconds
        for _ in 0 ..< iterations {
            _ = EventPolicy.intent(for: event, configuration: configuration)
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
        let average = Double(elapsed) / Double(iterations)

        print("JOSTLE_PERF event_policy_average_ns=\(Int(average)) iterations=\(iterations)")
        XCTAssertLessThan(average, 50_000)
    }

    func testSmoothingEngineBaseline() {
        let smoothing = EffectiveScrollSmoothingSettings(
            preset: .easeInOut,
            response: 0.68,
            speed: 1.02,
            acceleration: 1.1,
            inertia: 0.74,
            bouncing: true
        )
        let engine = ScrollSmoothingEngine(horizontal: smoothing, vertical: smoothing)
        let iterations = 100_000

        let startedAt = DispatchTime.now().uptimeNanoseconds
        for step in 0 ..< iterations {
            let timestamp = Double(step) / 120
            if step.isMultiple(of: 8) {
                engine.feed(
                    deltaX: 12,
                    deltaY: 36,
                    timestamp: timestamp,
                    inputKind: .wheel
                )
            }
            _ = engine.advance(to: timestamp)
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
        let average = Double(elapsed) / Double(iterations)

        print("JOSTLE_PERF smoothing_advance_average_ns=\(Int(average)) iterations=\(iterations)")
        XCTAssertLessThan(average, 50_000)
    }
}
