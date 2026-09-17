import Foundation
import JostleCore

final class SettingsStore {
    static let storageKey = "Jostle.settings"

    private let userDefaults: UserDefaults
    private let storageKey: String
    private(set) var settings: JostleSettings

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = SettingsStore.storageKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(JostleSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaults
        }
    }

    func update(_ mutation: (inout JostleSettings) -> Void) {
        var updated = settings
        mutation(&updated)
        persist(updated)
    }

    func reset() {
        persist(.defaults)
    }

    private func persist(_ updated: JostleSettings) {
        guard let data = try? JSONEncoder().encode(updated) else {
            assertionFailure("Jostle settings must always be encodable")
            return
        }
        userDefaults.set(data, forKey: storageKey)
        settings = updated
    }
}
