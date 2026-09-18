import Darwin
import Foundation

private func continuousTime() -> TimeInterval {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let nanoseconds = Double(mach_continuous_time())
        * Double(timebase.numer) / Double(timebase.denom)
    return nanoseconds / 1_000_000_000
}

protocol KeepAwakeTimerServicing: AnyObject {
    var remainingTime: TimeInterval? { get }
    var isPaused: Bool { get }
    var onCompletion: (() -> Void)? { get set }

    func start(duration: TimeInterval)
    func pause()
    func resume()
    func cancel()
}

final class KeepAwakeTimer: KeepAwakeTimerServicing, @unchecked Sendable {
    var onCompletion: (() -> Void)?

    private let queue: DispatchQueue
    private let monotonicNow: () -> TimeInterval
    private var continuousTask: Task<Void, Never>?
    private var storedRemaining: TimeInterval?
    private var deadline: TimeInterval?
    private var scheduleGeneration: UInt = 0

    init(
        queue: DispatchQueue = .main,
        monotonicNow: @escaping () -> TimeInterval = { continuousTime() }
    ) {
        self.queue = queue
        self.monotonicNow = monotonicNow
    }

    deinit {
        cancelScheduledTimer()
    }

    var remainingTime: TimeInterval? {
        guard let storedRemaining else { return nil }
        guard let deadline else { return storedRemaining }
        return max(0, min(storedRemaining, deadline - now))
    }

    var isPaused: Bool {
        storedRemaining != nil && deadline == nil
    }

    func start(duration: TimeInterval) {
        cancel()
        guard duration.isFinite, duration > 0 else {
            return
        }
        storedRemaining = duration
        schedule(after: duration)
    }

    func pause() {
        guard deadline != nil, let remainingTime else { return }
        storedRemaining = remainingTime
        deadline = nil
        cancelScheduledTimer()
    }

    func resume() {
        guard deadline == nil, let remaining = storedRemaining else { return }
        if remaining <= 0 {
            complete()
        } else {
            schedule(after: remaining)
        }
    }

    func cancel() {
        cancelScheduledTimer()
        storedRemaining = nil
        deadline = nil
    }

    private var now: TimeInterval {
        monotonicNow()
    }

    private func schedule(after interval: TimeInterval) {
        cancelScheduledTimer()
        storedRemaining = interval
        deadline = now + interval
        let generation = scheduleGeneration

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(interval))
        continuousTask = Task { [weak self] in
            do {
                try await clock.sleep(until: deadline)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.queue.async { [weak self] in
                self?.complete(ifGenerationMatches: generation)
            }
        }
    }

    private func cancelScheduledTimer() {
        scheduleGeneration &+= 1
        continuousTask?.cancel()
        continuousTask = nil
    }

    private func complete(ifGenerationMatches expectedGeneration: UInt? = nil) {
        guard expectedGeneration == nil || expectedGeneration == scheduleGeneration,
              storedRemaining != nil else {
            return
        }
        cancelScheduledTimer()
        storedRemaining = nil
        deadline = nil
        onCompletion?()
    }
}
