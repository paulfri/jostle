public struct JostleSettings: Codable, Equatable, Sendable {
    public var modifiers: Set<Modifier>
    public var bringWindowToFront: Bool
    public var middleClickResize: Bool
    public var resizeOnly: Bool
    public var excludedApplications: [String: String]

    public init(
        modifiers: Set<Modifier> = [.control, .command],
        bringWindowToFront: Bool = false,
        middleClickResize: Bool = false,
        resizeOnly: Bool = false,
        excludedApplications: [String: String] = [:]
    ) {
        self.modifiers = modifiers
        self.bringWindowToFront = bringWindowToFront
        self.middleClickResize = middleClickResize
        self.resizeOnly = resizeOnly
        self.excludedApplications = excludedApplications
    }

    public static let defaults = JostleSettings()

    public mutating func setModifier(_ modifier: Modifier, enabled: Bool) {
        if enabled {
            modifiers.insert(modifier)
        } else {
            modifiers.remove(modifier)
        }
    }

    public mutating func setApplicationExcluded(
        key: String,
        displayName: String?,
        excluded: Bool
    ) {
        guard !key.isEmpty else { return }
        if excluded {
            excludedApplications[key] = displayName.flatMap { $0.isEmpty ? nil : $0 } ?? key
        } else {
            excludedApplications.removeValue(forKey: key)
        }
    }
}

public enum ApplicationIdentity {
    public static func key(bundleIdentifier: String?, localizedName: String?) -> String? {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }
        if let localizedName, !localizedName.isEmpty {
            return localizedName
        }
        return nil
    }
}
