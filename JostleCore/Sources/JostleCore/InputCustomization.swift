public enum PointingDeviceCategory: String, CaseIterable, Codable, Equatable, Sendable {
    case mouse
    case trackpad
    case unknown

    public var title: String {
        switch self {
        case .mouse: "Mouse"
        case .trackpad: "Trackpad"
        case .unknown: "Unknown Device"
        }
    }
}

public enum PointerButtonAction: String, CaseIterable, Codable, Equatable, Sendable {
    case systemDefault
    case back
    case forward
    case moveWindow
    case resizeWindow
    case toggleMaximize
    case tileLeft
    case tileRight
    case moveToNextDisplay
    case toggleKeepAwake

    public var title: String {
        switch self {
        case .systemDefault: "System Default"
        case .back: "Back"
        case .forward: "Forward"
        case .moveWindow: "Move Window"
        case .resizeWindow: "Resize Window"
        case .toggleMaximize: "Maximize / Restore"
        case .tileLeft: "Tile Left"
        case .tileRight: "Tile Right"
        case .moveToNextDisplay: "Move to Next Display"
        case .toggleKeepAwake: "Toggle Keep Awake"
        }
    }

    public var beginsWindowGesture: Bool {
        self == .moveWindow || self == .resizeWindow
    }
}

public struct PointingDeviceRule: Codable, Equatable, Sendable {
    public var displayName: String
    public var category: PointingDeviceCategory
    public var reverseScrolling: ApplicationFeatureSetting
    public var focusFollowsPointer: ApplicationFeatureSetting

    public init(
        displayName: String,
        category: PointingDeviceCategory,
        reverseScrolling: ApplicationFeatureSetting = .useDefault,
        focusFollowsPointer: ApplicationFeatureSetting = .useDefault
    ) {
        self.displayName = displayName
        self.category = category
        self.reverseScrolling = reverseScrolling
        self.focusFollowsPointer = focusFollowsPointer
    }
}

public struct InputCustomizationSettings: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var isEnabled: Bool
    public var reverseMouseScrolling: Bool
    public var reverseTrackpadScrolling: Bool
    public var universalBackForward: Bool
    public var buttonFourAction: PointerButtonAction
    public var buttonFiveAction: PointerButtonAction
    public var focusFollowsPointerForMouse: Bool
    public var focusFollowsPointerForTrackpad: Bool
    public var deviceRules: [String: PointingDeviceRule]

    public init(
        schemaVersion: Int = 1,
        isEnabled: Bool = false,
        reverseMouseScrolling: Bool = false,
        reverseTrackpadScrolling: Bool = false,
        universalBackForward: Bool = false,
        buttonFourAction: PointerButtonAction = .systemDefault,
        buttonFiveAction: PointerButtonAction = .systemDefault,
        focusFollowsPointerForMouse: Bool = true,
        focusFollowsPointerForTrackpad: Bool = true,
        deviceRules: [String: PointingDeviceRule] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.reverseMouseScrolling = reverseMouseScrolling
        self.reverseTrackpadScrolling = reverseTrackpadScrolling
        self.universalBackForward = universalBackForward
        self.buttonFourAction = buttonFourAction
        self.buttonFiveAction = buttonFiveAction
        self.focusFollowsPointerForMouse = focusFollowsPointerForMouse
        self.focusFollowsPointerForTrackpad = focusFollowsPointerForTrackpad
        self.deviceRules = deviceRules
    }

    public static let defaults = InputCustomizationSettings()

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case isEnabled
        case reverseMouseScrolling
        case reverseTrackpadScrolling
        case universalBackForward
        case buttonFourAction
        case buttonFiveAction
        case focusFollowsPointerForMouse
        case focusFollowsPointerForTrackpad
        case deviceRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        reverseMouseScrolling = try container.decodeIfPresent(
            Bool.self,
            forKey: .reverseMouseScrolling
        ) ?? false
        reverseTrackpadScrolling = try container.decodeIfPresent(
            Bool.self,
            forKey: .reverseTrackpadScrolling
        ) ?? false
        universalBackForward = try container.decodeIfPresent(
            Bool.self,
            forKey: .universalBackForward
        ) ?? false
        buttonFourAction = try container.decodeIfPresent(
            PointerButtonAction.self,
            forKey: .buttonFourAction
        ) ?? .systemDefault
        buttonFiveAction = try container.decodeIfPresent(
            PointerButtonAction.self,
            forKey: .buttonFiveAction
        ) ?? .systemDefault
        focusFollowsPointerForMouse = try container.decodeIfPresent(
            Bool.self,
            forKey: .focusFollowsPointerForMouse
        ) ?? true
        focusFollowsPointerForTrackpad = try container.decodeIfPresent(
            Bool.self,
            forKey: .focusFollowsPointerForTrackpad
        ) ?? true
        deviceRules = try container.decodeIfPresent(
            [String: PointingDeviceRule].self,
            forKey: .deviceRules
        ) ?? [:]
    }

    public func reverseScrolling(
        forDeviceKey deviceKey: String?,
        category: PointingDeviceCategory
    ) -> Bool {
        let categoryDefault: Bool
        switch category {
        case .mouse:
            categoryDefault = reverseMouseScrolling
        case .trackpad:
            categoryDefault = reverseTrackpadScrolling
        case .unknown:
            categoryDefault = false
        }
        guard let deviceKey, let rule = deviceRules[deviceKey] else {
            return categoryDefault
        }
        return rule.reverseScrolling.resolve(default: categoryDefault)
    }

    public func allowsFocusFollowsPointer(
        forDeviceKey deviceKey: String?,
        category: PointingDeviceCategory
    ) -> Bool {
        let categoryDefault: Bool
        switch category {
        case .mouse:
            categoryDefault = focusFollowsPointerForMouse
        case .trackpad:
            categoryDefault = focusFollowsPointerForTrackpad
        case .unknown:
            categoryDefault = true
        }
        guard let deviceKey, let rule = deviceRules[deviceKey] else {
            return categoryDefault
        }
        return rule.focusFollowsPointer.resolve(default: categoryDefault)
    }

    public func action(forButtonNumber buttonNumber: Int) -> PointerButtonAction {
        let configured: PointerButtonAction
        switch buttonNumber {
        case 3:
            configured = buttonFourAction
        case 4:
            configured = buttonFiveAction
        default:
            return .systemDefault
        }
        guard configured == .systemDefault, universalBackForward else {
            return configured
        }
        return buttonNumber == 3 ? .back : .forward
    }

    public mutating func setDeviceRule(
        key: String,
        displayName: String,
        category: PointingDeviceCategory,
        reverseScrolling: ApplicationFeatureSetting? = nil,
        focusFollowsPointer: ApplicationFeatureSetting? = nil
    ) {
        guard !key.isEmpty else { return }
        var rule = deviceRules[key] ?? PointingDeviceRule(
            displayName: displayName,
            category: category
        )
        rule.displayName = displayName
        rule.category = category
        if let reverseScrolling {
            rule.reverseScrolling = reverseScrolling
        }
        if let focusFollowsPointer {
            rule.focusFollowsPointer = focusFollowsPointer
        }
        deviceRules[key] = rule
    }

    public mutating func removeDeviceRule(key: String) {
        deviceRules.removeValue(forKey: key)
    }
}

public enum PointerButtonGestureIntent: Equatable, Sendable {
    case passThrough
    case beginMove
    case beginResize
    case continueMove
    case continueResize
    case end
}

public enum PointerButtonGesturePolicy {
    public static func intent(
        eventType: InputEventType,
        buttonNumber: Int?,
        configuredAction: PointerButtonAction,
        activeButtonNumber: Int?,
        activeAction: PointerButtonAction?
    ) -> PointerButtonGestureIntent {
        if let activeButtonNumber,
           let activeAction {
            guard buttonNumber == activeButtonNumber else {
                return .passThrough
            }
            switch eventType {
            case .mouseDragged:
                return activeAction == .resizeWindow ? .continueResize : .continueMove
            case .mouseUp:
                return .end
            default:
                return .passThrough
            }
        }

        guard eventType == .mouseDown,
              buttonNumber != nil else {
            return .passThrough
        }
        switch configuredAction {
        case .moveWindow:
            return .beginMove
        case .resizeWindow:
            return .beginResize
        default:
            return .passThrough
        }
    }
}
