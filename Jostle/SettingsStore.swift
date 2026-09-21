import Combine
import Foundation
import JostleCore

struct InputCustomizationBackup: Codable, Equatable {
    static let formatIdentifier = "fm.pau.jostle.input-customization"
    static let currentFormatVersion = 1

    var format: String
    var formatVersion: Int
    var inputCustomization: InputCustomizationSettings

    init(inputCustomization: InputCustomizationSettings) {
        format = Self.formatIdentifier
        formatVersion = Self.currentFormatVersion
        self.inputCustomization = inputCustomization
    }
}

enum InputCustomizationBackupError: LocalizedError, Equatable {
    case invalidFormat
    case unsupportedVersion(Int)
    case unsupportedSettingsSchema(Int)
    case duplicateProfileIdentifier
    case emptyProfileIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "This file is not a Jostle input-customization backup."
        case let .unsupportedVersion(version):
            "Input backup version \(version) is not supported by this version of Jostle."
        case let .unsupportedSettingsSchema(version):
            "Input settings schema \(version) requires a newer version of Jostle."
        case .duplicateProfileIdentifier:
            "The backup contains duplicate scroll-profile identifiers."
        case .emptyProfileIdentifier:
            "The backup contains a scroll profile without an identifier."
        }
    }
}

final class SettingsStore: ObservableObject {
    static let storageKey = "Jostle.settings"

    private let userDefaults: UserDefaults
    private let storageKey: String
    @Published private(set) var settings: JostleSettings
    var onChange: (() -> Void)?

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

    func resetInputCustomization() {
        update { $0.inputCustomization = .defaults }
    }

    func exportInputCustomization() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(InputCustomizationBackup(
            inputCustomization: settings.inputCustomization
        ))
    }

    func importInputCustomization(from data: Data) throws {
        let backup = try JSONDecoder().decode(InputCustomizationBackup.self, from: data)
        guard backup.format == InputCustomizationBackup.formatIdentifier else {
            throw InputCustomizationBackupError.invalidFormat
        }
        guard backup.formatVersion == InputCustomizationBackup.currentFormatVersion else {
            throw InputCustomizationBackupError.unsupportedVersion(backup.formatVersion)
        }
        guard backup.inputCustomization.schemaVersion
            <= InputCustomizationSettings.defaults.schemaVersion else {
            throw InputCustomizationBackupError.unsupportedSettingsSchema(
                backup.inputCustomization.schemaVersion
            )
        }
        let profileIdentifiers = backup.inputCustomization.scrollProfiles.map(\.id)
        guard profileIdentifiers.allSatisfy({ !$0.isEmpty }) else {
            throw InputCustomizationBackupError.emptyProfileIdentifier
        }
        guard Set(profileIdentifiers).count == profileIdentifiers.count else {
            throw InputCustomizationBackupError.duplicateProfileIdentifier
        }
        update { $0.inputCustomization = backup.inputCustomization }
    }

    private func persist(_ updated: JostleSettings) {
        guard let data = try? JSONEncoder().encode(updated) else {
            assertionFailure("Jostle settings must always be encodable")
            return
        }
        userDefaults.set(data, forKey: storageKey)
        settings = updated
        onChange?()
    }
}
