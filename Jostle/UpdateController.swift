import Combine
import Sparkle

protocol UpdateControlling: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool)
    func checkForUpdates()
}

final class SparkleUpdateController: ObservableObject, UpdateControlling {
    private let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?
    @Published private(set) var canCheckForUpdates = false

    init(startingUpdater: Bool = true) {
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let canCheckForUpdates = change.newValue else { return }
            DispatchQueue.main.async {
                self?.canCheckForUpdates = canCheckForUpdates
            }
        }
    }

    var automaticallyChecksForUpdates: Bool {
        controller.updater.automaticallyChecksForUpdates
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
