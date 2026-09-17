public typealias MonotonicTime = UInt64

public struct GestureContext: Equatable, Sendable {
    public var frame: Frame
    public var resizeSection: ResizeSection
    public var lastWriteTime: MonotonicTime
    public var geometryDirty: Bool

    public init(
        frame: Frame,
        resizeSection: ResizeSection,
        lastWriteTime: MonotonicTime,
        geometryDirty: Bool = false
    ) {
        self.frame = frame
        self.resizeSection = resizeSection
        self.lastWriteTime = lastWriteTime
        self.geometryDirty = geometryDirty
    }
}

public enum GestureState: Equatable, Sendable {
    case idle
    case moving(GestureContext)
    case resizing(GestureContext)

    public var isActive: Bool {
        self != .idle
    }

    public var context: GestureContext? {
        switch self {
        case .idle:
            return nil
        case let .moving(context), let .resizing(context):
            return context
        }
    }
}

public enum GestureInput: Equatable, Sendable {
    case beginMove(frame: Frame, timestamp: MonotonicTime)
    case beginResize(frame: Frame, section: ResizeSection, timestamp: MonotonicTime)
    case moveBy(deltaX: Double, deltaY: Double, timestamp: MonotonicTime)
    case resizeBy(deltaX: Double, deltaY: Double, timestamp: MonotonicTime)
    case end(timestamp: MonotonicTime)
    case cancel(timestamp: MonotonicTime)
}

public struct GestureConfiguration: Equatable, Sendable {
    public var moveThrottleInterval: MonotonicTime
    public var resizeThrottleInterval: MonotonicTime

    public init(moveThrottleInterval: MonotonicTime, resizeThrottleInterval: MonotonicTime) {
        self.moveThrottleInterval = moveThrottleInterval
        self.resizeThrottleInterval = resizeThrottleInterval
    }
}

public enum GestureCommand: Equatable, Sendable {
    case setPosition(Point)
    case setSize(Size)
}

public struct GestureTransition: Equatable, Sendable {
    public var state: GestureState
    public var commands: [GestureCommand]

    public init(state: GestureState, commands: [GestureCommand]) {
        self.state = state
        self.commands = commands
    }
}

public enum GestureEngine {
    public static func reduce(
        state: GestureState,
        input: GestureInput,
        configuration: GestureConfiguration
    ) -> GestureTransition {
        switch input {
        case let .beginMove(frame, timestamp):
            let context = GestureContext(
                frame: frame,
                resizeSection: .none,
                lastWriteTime: timestamp
            )
            return GestureTransition(state: .moving(context), commands: [])

        case let .beginResize(frame, section, timestamp):
            let context = GestureContext(
                frame: frame,
                resizeSection: section,
                lastWriteTime: timestamp
            )
            return GestureTransition(state: .resizing(context), commands: [])

        case let .moveBy(deltaX, deltaY, timestamp):
            guard case var .moving(context) = state else {
                return GestureTransition(state: state, commands: [])
            }
            context.frame.origin = GeometryPolicy.move(
                context.frame.origin,
                deltaX: deltaX,
                deltaY: deltaY
            )
            context.geometryDirty = true
            var commands: [GestureCommand] = []
            if throttleIntervalElapsed(
                timestamp: timestamp,
                lastWriteTime: context.lastWriteTime,
                interval: configuration.moveThrottleInterval
            ) {
                commands = commandsForMoving(context)
                context.lastWriteTime = timestamp
                context.geometryDirty = false
            }
            return GestureTransition(state: .moving(context), commands: commands)

        case let .resizeBy(deltaX, deltaY, timestamp):
            guard case var .resizing(context) = state else {
                return GestureTransition(state: state, commands: [])
            }
            context.frame = GeometryPolicy.resize(
                context.frame,
                section: context.resizeSection,
                deltaX: deltaX,
                deltaY: deltaY
            )
            context.geometryDirty = true
            var commands: [GestureCommand] = []
            if throttleIntervalElapsed(
                timestamp: timestamp,
                lastWriteTime: context.lastWriteTime,
                interval: configuration.resizeThrottleInterval
            ) {
                commands = commandsForResizing(context)
                context.lastWriteTime = timestamp
                context.geometryDirty = false
            }
            return GestureTransition(state: .resizing(context), commands: commands)

        case .end:
            let commands: [GestureCommand]
            switch state {
            case let .moving(context) where context.geometryDirty:
                commands = commandsForMoving(context)
            case let .resizing(context) where context.geometryDirty:
                commands = commandsForResizing(context)
            default:
                commands = []
            }
            return GestureTransition(state: .idle, commands: commands)

        case .cancel:
            return GestureTransition(state: .idle, commands: [])
        }
    }

    private static func throttleIntervalElapsed(
        timestamp: MonotonicTime,
        lastWriteTime: MonotonicTime,
        interval: MonotonicTime
    ) -> Bool {
        timestamp > lastWriteTime && timestamp - lastWriteTime > interval
    }

    private static func commandsForMoving(_ context: GestureContext) -> [GestureCommand] {
        [.setPosition(context.frame.origin)]
    }

    private static func commandsForResizing(_ context: GestureContext) -> [GestureCommand] {
        var commands: [GestureCommand] = []
        if context.resizeSection.changesOrigin {
            commands.append(.setPosition(context.frame.origin))
        }
        commands.append(.setSize(context.frame.size))
        return commands
    }
}
