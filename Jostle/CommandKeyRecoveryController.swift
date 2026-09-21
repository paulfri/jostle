import AppKit
import JostleCore

final class CommandKeyRecoveryController {
    typealias Scheduler = (_ delay: TimeInterval, _ action: @escaping () -> Void) -> Void
    typealias EventPoster = (_ processIdentifier: pid_t, _ isKeyDown: Bool) -> Void

    private static let commandKeyCode: CGKeyCode = 0x37
    private static let activationDelay: TimeInterval = 0.08
    private static let retryDelay: TimeInterval = 0.05
    private static let keyTapDuration: TimeInterval = 0.03
    private static let maximumModifierWaitAttempts = 20

    private let settingsStore: SettingsStore
    private let safeMode: Bool
    private let notificationCenter: NotificationCenter
    private let frontmostProcessIdentifier: () -> pid_t?
    private let modifierFlags: () -> NSEvent.ModifierFlags
    private let scheduler: Scheduler
    private let eventPoster: EventPoster
    private var activationObserver: NSObjectProtocol?
    private var activationGeneration: UInt64 = 0
    private var sessionActive = true

    init(
        settingsStore: SettingsStore,
        safeMode: Bool,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        frontmostProcessIdentifier: @escaping () -> pid_t? = {
            NSWorkspace.shared.frontmostApplication?.processIdentifier
        },
        modifierFlags: @escaping () -> NSEvent.ModifierFlags = {
            NSEvent.modifierFlags
        },
        scheduler: @escaping Scheduler = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        },
        eventPoster: @escaping EventPoster = CommandKeyRecoveryController.postCommandEvent
    ) {
        self.settingsStore = settingsStore
        self.safeMode = safeMode
        self.notificationCenter = notificationCenter
        self.frontmostProcessIdentifier = frontmostProcessIdentifier
        self.modifierFlags = modifierFlags
        self.scheduler = scheduler
        self.eventPoster = eventPoster
    }

    deinit {
        stop()
    }

    func start() {
        guard activationObserver == nil else { return }
        activationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  let applicationInfo = RunningApplicationInfo(application: application) else {
                return
            }
            self?.applicationDidActivate(
                processIdentifier: application.processIdentifier,
                applicationKey: applicationInfo.key
            )
        }
    }

    func stop() {
        activationGeneration &+= 1
        if let activationObserver {
            notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    func setSessionActive(_ active: Bool) {
        sessionActive = active
        if !active {
            activationGeneration &+= 1
        }
    }

    func applicationDidActivate(
        processIdentifier: pid_t,
        applicationKey: String
    ) {
        activationGeneration &+= 1
        let generation = activationGeneration
        guard shouldRecover(applicationKey: applicationKey) else { return }

        scheduler(Self.activationDelay) { [weak self] in
            self?.attemptRecovery(
                processIdentifier: processIdentifier,
                applicationKey: applicationKey,
                activationGeneration: generation,
                remainingModifierWaitAttempts: Self.maximumModifierWaitAttempts
            )
        }
    }

    private func attemptRecovery(
        processIdentifier: pid_t,
        applicationKey: String,
        activationGeneration: UInt64,
        remainingModifierWaitAttempts: Int
    ) {
        guard activationGeneration == self.activationGeneration,
              sessionActive,
              frontmostProcessIdentifier() == processIdentifier,
              shouldRecover(applicationKey: applicationKey) else {
            return
        }

        guard physicallyHeldModifiers.isEmpty else {
            guard remainingModifierWaitAttempts > 0 else { return }
            scheduler(Self.retryDelay) { [weak self] in
                self?.attemptRecovery(
                    processIdentifier: processIdentifier,
                    applicationKey: applicationKey,
                    activationGeneration: activationGeneration,
                    remainingModifierWaitAttempts: remainingModifierWaitAttempts - 1
                )
            }
            return
        }

        let eventPoster = eventPoster
        eventPoster(processIdentifier, true)
        scheduler(Self.keyTapDuration) {
            eventPoster(processIdentifier, false)
        }
    }

    private func shouldRecover(applicationKey: String) -> Bool {
        guard !safeMode,
              settingsStore.settings.inputCustomization.isEnabled else {
            return false
        }
        return settingsStore.settings.commandKeyRecoveryEnabled(
            forApplicationKey: applicationKey
        )
    }

    private var physicallyHeldModifiers: NSEvent.ModifierFlags {
        modifierFlags().intersection([
            .command,
            .option,
            .control,
            .shift,
            .function,
        ])
    }

    private static func postCommandEvent(
        processIdentifier: pid_t,
        isKeyDown: Bool
    ) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: commandKeyCode,
            keyDown: isKeyDown
        ) else {
            return
        }
        event.flags = isKeyDown ? .maskCommand : []
        event.setIntegerValueField(
            .eventSourceUserData,
            value: EventTapController.syntheticEventMarker
        )
        event.postToPid(processIdentifier)
    }
}
