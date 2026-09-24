import Foundation
import JostleCore

/// Applies gesture frame writes off the event tap.
///
/// An Accessibility frame write blocks until the target app has laid out its window at
/// the new size. For a heavy window that takes longer than one display refresh, and done
/// inside the event tap it stalls the tap: mouse events queue behind it for the rest of
/// the drag and the window trails the pointer further and further. The writer keeps only
/// the most recent request and applies requests one at a time on its own queue, so the
/// tap returns at once and the window follows at whatever rate the app can lay out.
final class WindowFrameWriter {
    struct Request {
        var generation: UInt64
        var target: AccessibilityWindowTarget
        var commands: [GestureCommand]
        var minimumWindowSize: Size?
    }

    struct Result {
        var generation: UInt64
        var identity: AccessibilityWindowIdentity
        /// The window's frame after the write, or `nil` when the write failed.
        var actualFrame: Frame?
    }

    typealias Perform = (Request) -> Frame?

    /// Called on the main queue once per applied request. Coalesced requests produce no result.
    var onResult: ((Result) -> Void)?

    private let perform: Perform
    private let queue = DispatchQueue(label: "fm.pau.jostle.window-frame-writer", qos: .userInteractive)
    private let lock = NSLock()
    private var pending: Request?
    private var draining = false

    init(perform: @escaping Perform) {
        self.perform = perform
    }

    convenience init(windowSystem: AccessibilityWindowSystem) {
        self.init { request in
            guard windowSystem.apply(
                request.commands,
                to: request.target,
                minimumWindowSize: request.minimumWindowSize
            ) else {
                return nil
            }
            return windowSystem.frame(of: request.target)
        }
    }

    /// Replaces any request not yet started; the newest frame is the only one worth writing.
    func submit(_ request: Request) {
        lock.lock()
        pending = request
        let shouldStart = !draining
        draining = true
        lock.unlock()
        if shouldStart {
            queue.async { [self] in drain() }
        }
    }

    /// Blocks until every submitted request has been applied. Call before a synchronous
    /// frame write so that it lands after the gesture's writes rather than under them.
    func flush() {
        queue.sync {}
    }

    private func drain() {
        while true {
            lock.lock()
            guard let request = pending else {
                draining = false
                lock.unlock()
                return
            }
            pending = nil
            lock.unlock()

            let actual = perform(request)
            let result = Result(
                generation: request.generation,
                identity: request.target.identity,
                actualFrame: actual
            )
            if let onResult {
                DispatchQueue.main.async { onResult(result) }
            }
        }
    }
}
