public struct JostleSettings: Codable, Equatable, Sendable {
    public var modifiers: Set<Modifier>
    public var bringWindowToFront: Bool
    public var middleClickResize: Bool
    public var resizeOnly: Bool
    public var resizeFeedbackEnabled: Bool
    public var doubleClickActionsEnabled: Bool
    public var snapEnabled: Bool
    public var snapGap: Double
    public var snapScreenMargin: Double
    public var excludedApplications: [String: String]

    public init(
        modifiers: Set<Modifier> = [.control, .command],
        bringWindowToFront: Bool = false,
        middleClickResize: Bool = false,
        resizeOnly: Bool = false,
        resizeFeedbackEnabled: Bool = true,
        doubleClickActionsEnabled: Bool = true,
        snapEnabled: Bool = true,
        snapGap: Double = 8,
        snapScreenMargin: Double = 0,
        excludedApplications: [String: String] = [:]
    ) {
        self.modifiers = modifiers
        self.bringWindowToFront = bringWindowToFront
        self.middleClickResize = middleClickResize
        self.resizeOnly = resizeOnly
        self.resizeFeedbackEnabled = resizeFeedbackEnabled
        self.doubleClickActionsEnabled = doubleClickActionsEnabled
        self.snapEnabled = snapEnabled
        self.snapGap = snapGap
        self.snapScreenMargin = snapScreenMargin
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

    private enum CodingKeys: String, CodingKey {
        case modifiers
        case bringWindowToFront
        case middleClickResize
        case resizeOnly
        case resizeFeedbackEnabled
        case doubleClickActionsEnabled
        case snapEnabled
        case snapGap
        case snapScreenMargin
        case excludedApplications
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modifiers = try container.decodeIfPresent(Set<Modifier>.self, forKey: .modifiers)
            ?? Self.defaults.modifiers
        bringWindowToFront = try container.decodeIfPresent(Bool.self, forKey: .bringWindowToFront)
            ?? Self.defaults.bringWindowToFront
        middleClickResize = try container.decodeIfPresent(Bool.self, forKey: .middleClickResize)
            ?? Self.defaults.middleClickResize
        resizeOnly = try container.decodeIfPresent(Bool.self, forKey: .resizeOnly)
            ?? Self.defaults.resizeOnly
        resizeFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .resizeFeedbackEnabled)
            ?? Self.defaults.resizeFeedbackEnabled
        doubleClickActionsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .doubleClickActionsEnabled
        ) ?? Self.defaults.doubleClickActionsEnabled
        snapEnabled = try container.decodeIfPresent(Bool.self, forKey: .snapEnabled)
            ?? Self.defaults.snapEnabled
        snapGap = try container.decodeIfPresent(Double.self, forKey: .snapGap)
            ?? Self.defaults.snapGap
        snapScreenMargin = try container.decodeIfPresent(Double.self, forKey: .snapScreenMargin)
            ?? Self.defaults.snapScreenMargin
        excludedApplications = try container.decodeIfPresent(
            [String: String].self,
            forKey: .excludedApplications
        ) ?? Self.defaults.excludedApplications
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(bringWindowToFront, forKey: .bringWindowToFront)
        try container.encode(middleClickResize, forKey: .middleClickResize)
        try container.encode(resizeOnly, forKey: .resizeOnly)
        try container.encode(resizeFeedbackEnabled, forKey: .resizeFeedbackEnabled)
        try container.encode(doubleClickActionsEnabled, forKey: .doubleClickActionsEnabled)
        try container.encode(snapEnabled, forKey: .snapEnabled)
        try container.encode(snapGap, forKey: .snapGap)
        try container.encode(snapScreenMargin, forKey: .snapScreenMargin)
        try container.encode(excludedApplications, forKey: .excludedApplications)
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
