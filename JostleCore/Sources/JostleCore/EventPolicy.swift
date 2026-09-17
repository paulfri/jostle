public enum Modifier: String, CaseIterable, Codable, Hashable, Sendable {
    case control
    case option
    case shift
    case command
    case capsLock
    case function
}

public enum MouseButton: String, Codable, Equatable, Sendable {
    case none
    case left
    case right
    case other
}

public enum InputEventType: Equatable, Sendable {
    case mouseDown
    case mouseDragged
    case mouseUp
    case keyDown
    case tapDisabledByTimeout
    case tapDisabledByUserInput
    case unknown
}

public struct InputEvent: Equatable, Sendable {
    public var type: InputEventType
    public var button: MouseButton
    public var modifiers: Set<Modifier>
    public var clickCount: Int
    public var keyCode: Int?

    public init(
        type: InputEventType,
        button: MouseButton,
        modifiers: Set<Modifier>,
        clickCount: Int = 1,
        keyCode: Int? = nil
    ) {
        self.type = type
        self.button = button
        self.modifiers = modifiers
        self.clickCount = clickCount
        self.keyCode = keyCode
    }
}

public struct EventPolicyConfiguration: Equatable, Sendable {
    public var sessionActive: Bool
    public var gestureActive: Bool
    public var middleClickResize: Bool
    public var resizeOnly: Bool
    public var requiredModifiers: Set<Modifier>
    public var doubleClickActionsEnabled: Bool
    public var ownedActionButton: MouseButton?

    public init(
        sessionActive: Bool,
        gestureActive: Bool,
        middleClickResize: Bool,
        resizeOnly: Bool,
        requiredModifiers: Set<Modifier>,
        doubleClickActionsEnabled: Bool = true,
        ownedActionButton: MouseButton? = nil
    ) {
        self.sessionActive = sessionActive
        self.gestureActive = gestureActive
        self.middleClickResize = middleClickResize
        self.resizeOnly = resizeOnly
        self.requiredModifiers = requiredModifiers
        self.doubleClickActionsEnabled = doubleClickActionsEnabled
        self.ownedActionButton = ownedActionButton
    }
}

public enum EventIntent: Equatable, Sendable {
    case passThrough
    case reenableEventTap
    case beginMove
    case continueMove
    case beginResize
    case continueResize
    case toggleMaximize
    case snapByRegion
    case endActionClick
    case cancelGesture
    case endGesture
}

public enum EventPolicy {
    public static func intent(for input: InputEvent, configuration: EventPolicyConfiguration) -> EventIntent {
        let resizeButton: MouseButton = configuration.middleClickResize ? .other : .right

        if input.type == .tapDisabledByTimeout || input.type == .tapDisabledByUserInput {
            return .reenableEventTap
        }

        if configuration.gestureActive,
           input.type == .keyDown,
           input.keyCode == 53 {
            return .cancelGesture
        }

        if let ownedActionButton = configuration.ownedActionButton,
           input.type == .mouseUp,
           input.button == ownedActionButton {
            return .endActionClick
        }

        if configuration.gestureActive,
           input.type == .mouseUp,
           input.button == .left || input.button == resizeButton {
            return .endGesture
        }

        guard configuration.sessionActive, !configuration.requiredModifiers.isEmpty else {
            return .passThrough
        }

        guard input.modifiers == configuration.requiredModifiers else {
            return .passThrough
        }

        switch input.type {
        case .mouseDown:
            if configuration.doubleClickActionsEnabled, input.clickCount == 2 {
                if input.button == .left, !configuration.resizeOnly {
                    return .toggleMaximize
                }
                if input.button == resizeButton {
                    return .snapByRegion
                }
            }
            if input.button == .left, !configuration.resizeOnly {
                return .beginMove
            }
            if input.button == resizeButton {
                return .beginResize
            }
        case .mouseDragged:
            guard configuration.gestureActive else {
                break
            }
            if input.button == .left {
                return .continueMove
            }
            if input.button == resizeButton {
                return .continueResize
            }
        case .mouseUp, .keyDown, .tapDisabledByTimeout, .tapDisabledByUserInput, .unknown:
            break
        }

        return .passThrough
    }
}
