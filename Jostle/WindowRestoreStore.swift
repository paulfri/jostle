import JostleCore

final class WindowRestoreStore {
    private let capacity: Int
    private var frames: [AccessibilityWindowIdentity: Frame] = [:]
    private var insertionOrder: [AccessibilityWindowIdentity] = []

    init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
    }

    func frame(for window: AccessibilityWindowIdentity) -> Frame? {
        frames[window]
    }

    func remember(_ frame: Frame, for window: AccessibilityWindowIdentity) {
        if frames[window] == nil {
            insertionOrder.append(window)
        }
        frames[window] = frame
        trimIfNeeded()
    }

    func removeFrame(for window: AccessibilityWindowIdentity) {
        frames.removeValue(forKey: window)
        insertionOrder.removeAll { $0 == window }
    }

    private func trimIfNeeded() {
        while frames.count > capacity, let oldest = insertionOrder.first {
            insertionOrder.removeFirst()
            frames.removeValue(forKey: oldest)
        }
    }
}
