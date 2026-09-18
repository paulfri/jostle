import Combine
import Foundation
import JostleCore

final class KeepAwakeController: ObservableObject {
    enum State: Equatable {
        case inactive
        case active(KeepAwakeDuration)
        case paused(KeepAwakeDuration, remaining: TimeInterval?)
    }

    @Published private(set) var state: State = .inactive
    @Published private(set) var lastErrorMessage: String?
    var onChange: (() -> Void)?

    private let settingsStore: SettingsStore
    private let powerAssertion: PowerAssertionServicing
    private let timer: KeepAwakeTimerServicing
    private let notifier: KeepAwakeCompletionNotifying
    private var settingsCancellable: AnyCancellable?
    private var previousSettings: JostleSettings
    private var screenIsLocked = false

    init(
        settingsStore: SettingsStore,
        powerAssertion: PowerAssertionServicing = PowerAssertionController(),
        timer: KeepAwakeTimerServicing = KeepAwakeTimer(),
        notifier: KeepAwakeCompletionNotifying = CompletionNotificationController()
    ) {
        self.settingsStore = settingsStore
        self.powerAssertion = powerAssertion
        self.timer = timer
        self.notifier = notifier
        previousSettings = settingsStore.settings

        timer.onCompletion = { [weak self] in
            if Thread.isMainThread {
                self?.timerDidComplete()
            } else {
                DispatchQueue.main.async {
                    self?.timerDidComplete()
                }
            }
        }
        settingsCancellable = settingsStore.$settings
            .dropFirst()
            .sink { [weak self] settings in
                self?.settingsDidChange(settings)
            }
    }

    deinit {
        timer.onCompletion = nil
        timer.cancel()
        powerAssertion.release()
    }

    var isEnabled: Bool {
        switch state {
        case .inactive: false
        case .active, .paused: true
        }
    }

    var isPreventingSleep: Bool {
        if case .active = state { return true }
        return false
    }

    var duration: KeepAwakeDuration? {
        switch state {
        case .inactive:
            nil
        case let .active(duration), let .paused(duration, _):
            duration
        }
    }

    var remainingTime: TimeInterval? {
        switch state {
        case .inactive:
            nil
        case .active:
            timer.remainingTime
        case let .paused(_, remaining):
            remaining
        }
    }

    func startDefault() {
        start(settingsStore.settings.keepAwakeDefaultDuration.duration)
    }

    func start(_ duration: KeepAwakeDuration) {
        guard duration.isValid else {
            reportError("The keep-awake duration must be greater than zero.")
            return
        }

        do {
            try powerAssertion.acquire(
                allowDisplaySleep: settingsStore.settings.keepAwakeAllowDisplaySleep
            )
        } catch {
            reportError(error.localizedDescription)
            return
        }

        lastErrorMessage = nil
        timer.cancel()
        if let seconds = duration.seconds {
            notifier.prepare()
            timer.start(duration: seconds)
        }
        state = .active(duration)

        if screenIsLocked && settingsStore.settings.keepAwakeAllowSleepWhenLocked {
            pauseForScreenLock()
        } else {
            notifyChange()
        }
    }

    func stop() {
        timer.cancel()
        powerAssertion.release()
        state = .inactive
        lastErrorMessage = nil
        notifyChange()
    }

    func shutdown() {
        timer.cancel()
        powerAssertion.release()
        state = .inactive
    }

    func toggle(duration requestedDuration: KeepAwakeDuration? = nil) {
        if isEnabled {
            stop()
        } else {
            start(requestedDuration ?? settingsStore.settings.keepAwakeDefaultDuration.duration)
        }
    }

    func perform(_ command: KeepAwakeCommand) {
        switch command {
        case let .activate(duration):
            start(duration ?? settingsStore.settings.keepAwakeDefaultDuration.duration)
        case .deactivate:
            stop()
        case let .toggle(duration):
            toggle(duration: duration)
        }
    }

    func reportAutomationError(_ error: Error) {
        reportError(error.localizedDescription)
    }

    func screenDidLock() {
        screenIsLocked = true
        guard settingsStore.settings.keepAwakeAllowSleepWhenLocked else { return }
        pauseForScreenLock()
    }

    func screenDidUnlock() {
        screenIsLocked = false
        resumeAfterScreenUnlock()
    }

    func powerSourceDidChange(from previous: PowerSource, to current: PowerSource) {
        guard previous == .external,
              current == .battery,
              settingsStore.settings.keepAwakeDeactivateOnBattery,
              isEnabled else {
            return
        }
        stop()
    }

    private func pauseForScreenLock() {
        guard case let .active(duration) = state else { return }
        timer.pause()
        let remaining = timer.remainingTime
        powerAssertion.release()
        state = .paused(duration, remaining: remaining)
        notifyChange()
    }

    private func resumeAfterScreenUnlock() {
        guard case let .paused(duration, remaining) = state else { return }
        do {
            try powerAssertion.acquire(
                allowDisplaySleep: settingsStore.settings.keepAwakeAllowDisplaySleep
            )
        } catch {
            timer.cancel()
            state = .inactive
            reportError(error.localizedDescription)
            return
        }

        if duration.seconds != nil {
            timer.resume()
        }
        state = .active(duration)
        if let remaining, remaining <= 0 {
            timerDidComplete()
        } else {
            lastErrorMessage = nil
            notifyChange()
        }
    }

    private func timerDidComplete() {
        guard isEnabled else { return }
        powerAssertion.release()
        timer.cancel()
        state = .inactive
        lastErrorMessage = nil
        notifier.notifyCompletion()
        notifyChange()
    }

    private func settingsDidChange(_ settings: JostleSettings) {
        let oldSettings = previousSettings
        previousSettings = settings

        if settings.keepAwakeAllowDisplaySleep != oldSettings.keepAwakeAllowDisplaySleep,
           isPreventingSleep {
            do {
                try powerAssertion.acquire(allowDisplaySleep: settings.keepAwakeAllowDisplaySleep)
                lastErrorMessage = nil
            } catch {
                reportError(error.localizedDescription)
            }
        }

        if settings.keepAwakeAllowSleepWhenLocked
            != oldSettings.keepAwakeAllowSleepWhenLocked,
           screenIsLocked {
            if settings.keepAwakeAllowSleepWhenLocked {
                pauseForScreenLock()
            } else {
                resumeAfterScreenUnlock()
            }
        }

        notifyChange()
    }

    private func reportError(_ message: String) {
        lastErrorMessage = message
        notifyChange()
    }

    private func notifyChange() {
        onChange?()
    }
}
