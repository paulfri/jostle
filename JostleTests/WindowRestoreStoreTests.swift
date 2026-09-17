import JostleCore
import XCTest
@testable import Jostle

final class WindowRestoreStoreTests: XCTestCase {
    func testFramesAreRememberedReplacedAndRemovedByWindow() {
        let store = WindowRestoreStore()
        let window = AccessibilityWindowIdentity(processIdentifier: 10, elementHash: 20)
        let first = Frame(x: 0, y: 0, width: 800, height: 600)
        let replacement = Frame(x: 20, y: 30, width: 900, height: 700)

        store.remember(first, for: window)
        XCTAssertEqual(store.frame(for: window), first)

        store.remember(replacement, for: window)
        XCTAssertEqual(store.frame(for: window), replacement)

        store.removeFrame(for: window)
        XCTAssertNil(store.frame(for: window))
    }

    func testOldestWindowIsEvictedAtCapacity() {
        let store = WindowRestoreStore(capacity: 2)
        let first = AccessibilityWindowIdentity(processIdentifier: 1, elementHash: 1)
        let second = AccessibilityWindowIdentity(processIdentifier: 2, elementHash: 2)
        let third = AccessibilityWindowIdentity(processIdentifier: 3, elementHash: 3)
        let frame = Frame(x: 0, y: 0, width: 800, height: 600)

        store.remember(frame, for: first)
        store.remember(frame, for: second)
        store.remember(frame, for: third)

        XCTAssertNil(store.frame(for: first))
        XCTAssertEqual(store.frame(for: second), frame)
        XCTAssertEqual(store.frame(for: third), frame)
    }
}
