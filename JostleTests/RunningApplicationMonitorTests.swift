import AppKit
import Combine
import XCTest
@testable import Jostle

final class RunningApplicationMonitorTests: XCTestCase {
    func testFiltersHelpersAndCurrentProcessWhileSortingAndDeduplicatingApps() {
        let monitor = RunningApplicationMonitor(
            notificationCenter: NotificationCenter(),
            candidatesProvider: {
                [
                    RunningApplicationCandidate(
                        processIdentifier: 10,
                        activationPolicy: .regular,
                        information: RunningApplicationInfo(
                            key: "com.example.Calendar",
                            name: "Calendar"
                        )
                    ),
                    RunningApplicationCandidate(
                        processIdentifier: 20,
                        activationPolicy: .regular,
                        information: RunningApplicationInfo(
                            key: "eqgame.exe",
                            name: "EverQuest"
                        )
                    ),
                    RunningApplicationCandidate(
                        processIdentifier: 21,
                        activationPolicy: .regular,
                        information: RunningApplicationInfo(
                            key: "eqgame.exe",
                            name: "eqgame.exe"
                        )
                    ),
                    RunningApplicationCandidate(
                        processIdentifier: 30,
                        activationPolicy: .prohibited,
                        information: RunningApplicationInfo(
                            key: "wine-helper",
                            name: "Wine Helper"
                        )
                    ),
                    RunningApplicationCandidate(
                        processIdentifier: 99,
                        activationPolicy: .regular,
                        information: RunningApplicationInfo(
                            key: "fm.pau.jostle.development",
                            name: "Jostle Development"
                        )
                    ),
                ]
            },
            currentProcessIdentifier: 99
        )

        XCTAssertEqual(
            monitor.applications,
            [
                RunningApplicationInfo(key: "com.example.Calendar", name: "Calendar"),
                RunningApplicationInfo(key: "eqgame.exe", name: "eqgame.exe"),
            ]
        )
    }

    func testRefreshesForWorkspaceLifecycleAndActivationNotifications() {
        let notificationNames = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]

        for notificationName in notificationNames {
            let notificationCenter = NotificationCenter()
            var candidates: [RunningApplicationCandidate] = []
            let monitor = RunningApplicationMonitor(
                notificationCenter: notificationCenter,
                candidatesProvider: { candidates },
                currentProcessIdentifier: 99
            )
            let refreshed = expectation(description: notificationName.rawValue)
            var cancellable: AnyCancellable?
            cancellable = monitor.$applications.dropFirst().sink { applications in
                if applications.contains(
                    RunningApplicationInfo(key: "eqgame.exe", name: "eqgame.exe")
                ) {
                    refreshed.fulfill()
                }
            }

            candidates = [
                RunningApplicationCandidate(
                    processIdentifier: 20,
                    activationPolicy: .regular,
                    information: RunningApplicationInfo(
                        key: "eqgame.exe",
                        name: "eqgame.exe"
                    )
                ),
            ]
            notificationCenter.post(name: notificationName, object: nil)

            wait(for: [refreshed], timeout: 1)
            XCTAssertEqual(monitor.applications.map(\.key), ["eqgame.exe"])
            withExtendedLifetime(cancellable) {}
        }
    }
}
