import JostleCore

enum WindowRestoreKind: Equatable {
    case snapped
    case maximized
}

struct WindowRestoreRecord: Equatable {
    let frame: Frame
    let kind: WindowRestoreKind
}

final class WindowRestoreStore {
    private let capacity: Int
    private var records: [AccessibilityWindowIdentity: WindowRestoreRecord] = [:]
    private var insertionOrder: [AccessibilityWindowIdentity] = []

    init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
    }

    func record(for window: AccessibilityWindowIdentity) -> WindowRestoreRecord? {
        records[window]
    }

    func frame(for window: AccessibilityWindowIdentity) -> Frame? {
        record(for: window)?.frame
    }

    func remember(
        _ frame: Frame,
        kind: WindowRestoreKind,
        for window: AccessibilityWindowIdentity
    ) {
        if records[window] == nil {
            insertionOrder.append(window)
        }
        records[window] = WindowRestoreRecord(frame: frame, kind: kind)
        trimIfNeeded()
    }

    func removeFrame(for window: AccessibilityWindowIdentity) {
        records.removeValue(forKey: window)
        insertionOrder.removeAll { $0 == window }
    }

    private func trimIfNeeded() {
        while records.count > capacity, let oldest = insertionOrder.first {
            insertionOrder.removeFirst()
            records.removeValue(forKey: oldest)
        }
    }
}
