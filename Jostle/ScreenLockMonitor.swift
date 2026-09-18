import Foundation

final class ScreenLockMonitor {
    var onLock: (() -> Void)?
    var onUnlock: (() -> Void)?

    private let center: DistributedNotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(center: DistributedNotificationCenter = .default()) {
        self.center = center
    }

    deinit {
        stop()
    }

    func start() {
        guard observers.isEmpty else { return }
        observers.append(
            center.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onLock?()
            }
        )
        observers.append(
            center.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onUnlock?()
            }
        )
    }

    func stop() {
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }
}
