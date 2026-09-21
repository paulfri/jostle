import AppKit
import Combine

struct RunningApplicationCandidate {
    let processIdentifier: pid_t
    let activationPolicy: NSApplication.ActivationPolicy
    let information: RunningApplicationInfo?

    init(
        processIdentifier: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        information: RunningApplicationInfo?
    ) {
        self.processIdentifier = processIdentifier
        self.activationPolicy = activationPolicy
        self.information = information
    }

    init(application: NSRunningApplication) {
        self.init(
            processIdentifier: application.processIdentifier,
            activationPolicy: application.activationPolicy,
            information: RunningApplicationInfo(application: application)
        )
    }
}

final class RunningApplicationMonitor: ObservableObject {
    @Published private(set) var applications: [RunningApplicationInfo] = []

    private let notificationCenter: NotificationCenter
    private let candidatesProvider: () -> [RunningApplicationCandidate]
    private let currentProcessIdentifier: pid_t
    private var observers: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        candidatesProvider: @escaping () -> [RunningApplicationCandidate] = {
            NSWorkspace.shared.runningApplications.map(RunningApplicationCandidate.init)
        },
        currentProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier
    ) {
        self.notificationCenter = notificationCenter
        self.candidatesProvider = candidatesProvider
        self.currentProcessIdentifier = currentProcessIdentifier

        refresh()
        observers = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ].map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        }
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    func refresh() {
        var applicationsByKey: [String: RunningApplicationInfo] = [:]
        for candidate in candidatesProvider()
        where candidate.processIdentifier != currentProcessIdentifier
            && candidate.activationPolicy == .regular {
            guard let information = candidate.information else { continue }
            applicationsByKey[information.key] = information
        }
        applications = applicationsByKey.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
