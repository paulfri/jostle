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
    public var keepAwakeDefaultDuration: KeepAwakeDurationPreset
    public var keepAwakeActivateAtLaunch: Bool
    public var keepAwakeActivateOnLeftClick: Bool
    public var keepAwakeAllowDisplaySleep: Bool
    public var keepAwakeAllowSleepWhenLocked: Bool
    public var keepAwakeDeactivateOnBattery: Bool
    public var keepAwakeDimWhenInactive: Bool
    public var keepAwakeIndicatorStyle: KeepAwakeIndicatorStyle
    public var keepAwakeUseImprovedTimer: Bool
    public var keepAwakeShortcut: GlobalShortcut?

    public init(
        modifiers: Set<Modifier> = [.control],
        bringWindowToFront: Bool = false,
        middleClickResize: Bool = false,
        resizeOnly: Bool = false,
        resizeFeedbackEnabled: Bool = true,
        doubleClickActionsEnabled: Bool = true,
        snapEnabled: Bool = true,
        snapGap: Double = 8,
        snapScreenMargin: Double = 0,
        excludedApplications: [String: String] = [:],
        keepAwakeDefaultDuration: KeepAwakeDurationPreset = .indefinitely,
        keepAwakeActivateAtLaunch: Bool = false,
        keepAwakeActivateOnLeftClick: Bool = false,
        keepAwakeAllowDisplaySleep: Bool = false,
        keepAwakeAllowSleepWhenLocked: Bool = false,
        keepAwakeDeactivateOnBattery: Bool = false,
        keepAwakeDimWhenInactive: Bool = false,
        keepAwakeIndicatorStyle: KeepAwakeIndicatorStyle = .normal,
        keepAwakeUseImprovedTimer: Bool = true,
        keepAwakeShortcut: GlobalShortcut? = nil
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
        self.keepAwakeDefaultDuration = keepAwakeDefaultDuration
        self.keepAwakeActivateAtLaunch = keepAwakeActivateAtLaunch
        self.keepAwakeActivateOnLeftClick = keepAwakeActivateOnLeftClick
        self.keepAwakeAllowDisplaySleep = keepAwakeAllowDisplaySleep
        self.keepAwakeAllowSleepWhenLocked = keepAwakeAllowSleepWhenLocked
        self.keepAwakeDeactivateOnBattery = keepAwakeDeactivateOnBattery
        self.keepAwakeDimWhenInactive = keepAwakeDimWhenInactive
        self.keepAwakeIndicatorStyle = keepAwakeIndicatorStyle
        self.keepAwakeUseImprovedTimer = keepAwakeUseImprovedTimer
        self.keepAwakeShortcut = keepAwakeShortcut
    }

    public static let defaults = JostleSettings()

    public mutating func setModifier(_ modifier: Modifier, enabled: Bool) {
        if enabled {
            modifiers.insert(modifier)
        } else if modifiers.count > 1 || !modifiers.contains(modifier) {
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
        case keepAwakeDefaultDuration
        case keepAwakeActivateAtLaunch
        case keepAwakeActivateOnLeftClick
        case keepAwakeAllowDisplaySleep
        case keepAwakeAllowSleepWhenLocked
        case keepAwakeDeactivateOnBattery
        case keepAwakeDimWhenInactive
        case keepAwakeIndicatorStyle
        case keepAwakeUseImprovedTimer
        case keepAwakeShortcut
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
        keepAwakeDefaultDuration = try container.decodeIfPresent(
            KeepAwakeDurationPreset.self,
            forKey: .keepAwakeDefaultDuration
        ) ?? Self.defaults.keepAwakeDefaultDuration
        keepAwakeActivateAtLaunch = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeActivateAtLaunch
        ) ?? Self.defaults.keepAwakeActivateAtLaunch
        keepAwakeActivateOnLeftClick = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeActivateOnLeftClick
        ) ?? Self.defaults.keepAwakeActivateOnLeftClick
        keepAwakeAllowDisplaySleep = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeAllowDisplaySleep
        ) ?? Self.defaults.keepAwakeAllowDisplaySleep
        keepAwakeAllowSleepWhenLocked = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeAllowSleepWhenLocked
        ) ?? Self.defaults.keepAwakeAllowSleepWhenLocked
        keepAwakeDeactivateOnBattery = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeDeactivateOnBattery
        ) ?? Self.defaults.keepAwakeDeactivateOnBattery
        keepAwakeDimWhenInactive = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeDimWhenInactive
        ) ?? Self.defaults.keepAwakeDimWhenInactive
        keepAwakeIndicatorStyle = try container.decodeIfPresent(
            KeepAwakeIndicatorStyle.self,
            forKey: .keepAwakeIndicatorStyle
        ) ?? Self.defaults.keepAwakeIndicatorStyle
        keepAwakeUseImprovedTimer = try container.decodeIfPresent(
            Bool.self,
            forKey: .keepAwakeUseImprovedTimer
        ) ?? Self.defaults.keepAwakeUseImprovedTimer
        keepAwakeShortcut = try container.decodeIfPresent(
            GlobalShortcut.self,
            forKey: .keepAwakeShortcut
        )
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
        try container.encode(keepAwakeDefaultDuration, forKey: .keepAwakeDefaultDuration)
        try container.encode(keepAwakeActivateAtLaunch, forKey: .keepAwakeActivateAtLaunch)
        try container.encode(keepAwakeActivateOnLeftClick, forKey: .keepAwakeActivateOnLeftClick)
        try container.encode(keepAwakeAllowDisplaySleep, forKey: .keepAwakeAllowDisplaySleep)
        try container.encode(keepAwakeAllowSleepWhenLocked, forKey: .keepAwakeAllowSleepWhenLocked)
        try container.encode(keepAwakeDeactivateOnBattery, forKey: .keepAwakeDeactivateOnBattery)
        try container.encode(keepAwakeDimWhenInactive, forKey: .keepAwakeDimWhenInactive)
        try container.encode(keepAwakeIndicatorStyle, forKey: .keepAwakeIndicatorStyle)
        try container.encode(keepAwakeUseImprovedTimer, forKey: .keepAwakeUseImprovedTimer)
        try container.encodeIfPresent(keepAwakeShortcut, forKey: .keepAwakeShortcut)
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
