import ApplicationServices
import JostleCore
import XCTest
@testable import Jostle

final class WindowFrameWriterTests: XCTestCase {
    private let target = AccessibilityWindowTarget(
        identity: AccessibilityWindowIdentity(processIdentifier: 1, elementHash: 1),
        element: AXUIElementCreateSystemWide(),
        application: nil,
        applicationInfo: nil
    )

    func testCoalescesToTheNewestRequestWhileBusy() {
        let applied = Locked<[UInt64]>([])
        let writer = WindowFrameWriter { request in
            applied.mutate { $0.append(request.generation) }
            Thread.sleep(forTimeInterval: 0.02)
            return Frame(x: 0, y: 0, width: 100, height: 100)
        }
        let finished = expectation(description: "results")
        let results = Locked<[UInt64]>([])
        writer.onResult = { result in
            results.mutate { $0.append(result.generation) }
            if result.generation == 20 { finished.fulfill() }
        }

        for generation in 1...20 {
            writer.submit(WindowFrameWriter.Request(
                generation: UInt64(generation),
                target: target,
                commands: [.setSize(Size(width: 100, height: 100))]
            ))
        }
        wait(for: [finished], timeout: 5)

        let appliedGenerations = applied.value
        XCTAssertEqual(appliedGenerations.last, 20)
        XCTAssertLessThan(appliedGenerations.count, 20, "intermediate requests should be dropped")
        XCTAssertEqual(appliedGenerations, appliedGenerations.sorted())
        XCTAssertEqual(results.value, appliedGenerations, "every applied request reports once, in order")
    }

    func testFlushWaitsForPendingWrites() {
        let applied = Locked(0)
        let writer = WindowFrameWriter { _ in
            Thread.sleep(forTimeInterval: 0.05)
            applied.mutate { $0 += 1 }
            return nil
        }
        writer.submit(WindowFrameWriter.Request(generation: 1, target: target, commands: []))
        writer.flush()
        XCTAssertEqual(applied.value, 1)
    }
}

private final class Locked<Value> {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) { storage = value }

    var value: Value {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func mutate(_ body: (inout Value) -> Void) {
        lock.lock(); defer { lock.unlock() }
        body(&storage)
    }
}
