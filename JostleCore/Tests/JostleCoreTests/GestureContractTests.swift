import Foundation
import XCTest
@testable import JostleCore

private struct ContractFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var coreValue: Frame {
        Frame(x: x, y: y, width: width, height: height)
    }

    init(_ frame: Frame) {
        x = frame.origin.x
        y = frame.origin.y
        width = frame.size.width
        height = frame.size.height
    }
}

private struct ContractConfiguration: Codable {
    var sessionActive: Bool
    var overallEnabled: Bool
    var requiredModifiers: [Modifier]
    var bringToFront: Bool
    var middleClickResize: Bool
    var resizeOnly: Bool
    var moveThrottleNanoseconds: UInt64
    var resizeThrottleNanoseconds: UInt64
}

private enum ContractStateKind: String, Codable {
    case idle
    case moving
    case resizing
}

private struct ContractGesture: Codable, Equatable {
    var windowId: String
    var applicationId: String?
    var frame: ContractFrame
    var horizontalEdge: HorizontalResizeEdge
    var verticalEdge: VerticalResizeEdge
    var lastWriteTimeNanoseconds: UInt64

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windowId, forKey: .windowId)
        if let applicationId {
            try container.encode(applicationId, forKey: .applicationId)
        } else {
            try container.encodeNil(forKey: .applicationId)
        }
        try container.encode(frame, forKey: .frame)
        try container.encode(horizontalEdge, forKey: .horizontalEdge)
        try container.encode(verticalEdge, forKey: .verticalEdge)
        try container.encode(lastWriteTimeNanoseconds, forKey: .lastWriteTimeNanoseconds)
    }
}

private struct ContractState: Codable, Equatable {
    var kind: ContractStateKind
    var gesture: ContractGesture?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        if let gesture {
            try container.encode(gesture, forKey: .gesture)
        } else {
            try container.encodeNil(forKey: .gesture)
        }
    }
}

private enum ContractTargetOutcome: String, Codable {
    case usable
    case excluded
    case notFound
    case queryFailed
}

private struct ContractTarget: Codable {
    var outcome: ContractTargetOutcome
    var windowId: String?
    var applicationId: String?
    var appKey: String?
    var frame: ContractFrame?
    var diagnostic: String?
}

private enum ContractEventType: String, Codable {
    case tapDisabledByTimeout
    case tapDisabledByUserInput
    case mouseDown
    case mouseDragged
    case mouseUp
    case sessionBecameActive
    case sessionBecameInactive
    case overallEnabled
    case overallDisabled
    case targetInvalidated
    case accessibilityTrustLost
}

private struct ContractEvent: Codable {
    var type: ContractEventType
    var timestampNanoseconds: UInt64
    var modifiers: [Modifier]
    var button: MouseButton?
    var pointer: Point?
    var delta: Point?
    var target: ContractTarget?
}

private enum ContractCommandType: String, Codable {
    case reenableEventTap
    case activateApplication
    case raiseWindow
    case setPosition
    case setSize
    case reportFailure
}

private struct ContractCommand: Codable, Equatable {
    var type: ContractCommandType
    var windowId: String?
    var applicationId: String?
    var position: Point?
    var size: Size?
    var code: String?

    init(
        type: ContractCommandType,
        windowId: String? = nil,
        applicationId: String? = nil,
        position: Point? = nil,
        size: Size? = nil,
        code: String? = nil
    ) {
        self.type = type
        self.windowId = windowId
        self.applicationId = applicationId
        self.position = position
        self.size = size
        self.code = code
    }
}

private enum ContractDisposition: String, Codable {
    case passThrough
    case consume
    case notApplicable
}

private struct ContractOutput: Codable, Equatable {
    var state: ContractState
    var commands: [ContractCommand]
    var disposition: ContractDisposition
    var diagnostics: [String]
}

private struct ContractExpectations: Codable {
    var objectiveC: ContractOutput
    var swiftOutput: ContractOutput

    enum CodingKeys: String, CodingKey {
        case objectiveC = "objective-c"
        case swiftOutput = "swift"
    }
}

private struct ContractStep: Codable {
    var event: ContractEvent
    var expected: ContractOutput?
    var expectations: ContractExpectations?

    var expectedSwiftOutput: ContractOutput {
        expected ?? expectations!.swiftOutput
    }
}

private struct ContractGiven: Codable {
    var configuration: ContractConfiguration
    var initialState: ContractState
}

private struct GestureContractFixture: Codable {
    var schemaVersion: Int
    var id: String
    var title: String
    var behaviorIds: [String]
    var mode: String
    var given: ContractGiven
    var steps: [ContractStep]
}

private final class SwiftGestureContractRunner {
    private var configuration: ContractConfiguration
    private var state: GestureState
    private var windowID: String?
    private var applicationID: String?

    init(fixture: GestureContractFixture) {
        configuration = fixture.given.configuration
        let initial = fixture.given.initialState
        guard let gesture = initial.gesture else {
            state = .idle
            return
        }

        windowID = gesture.windowId
        applicationID = gesture.applicationId
        let context = GestureContext(
            frame: gesture.frame.coreValue,
            resizeSection: ResizeSection(
                horizontalEdge: gesture.horizontalEdge,
                verticalEdge: gesture.verticalEdge
            ),
            lastWriteTime: gesture.lastWriteTimeNanoseconds
        )
        state = initial.kind == .moving ? .moving(context) : .resizing(context)
    }

    func run(_ event: ContractEvent) -> ContractOutput {
        if isLifecycleEvent(event.type) {
            return runLifecycleEvent(event)
        }

        let input = InputEvent(
            type: coreEventType(event.type),
            button: event.button ?? .none,
            modifiers: Set(event.modifiers)
        )
        let policy = EventPolicyConfiguration(
            sessionActive: configuration.sessionActive,
            gestureActive: state.isActive,
            middleClickResize: configuration.middleClickResize,
            resizeOnly: configuration.resizeOnly,
            requiredModifiers: Set(configuration.requiredModifiers)
        )
        let intent = configuration.overallEnabled
            ? EventPolicy.intent(for: input, configuration: policy)
            : .passThrough
        var commands: [ContractCommand] = []
        var diagnostics: [String] = []
        var disposition: ContractDisposition = intent == .passThrough ? .passThrough : .consume

        switch intent {
        case .passThrough:
            break

        case .reenableEventTap:
            commands.append(ContractCommand(type: .reenableEventTap))
            disposition = .passThrough

        case .beginMove, .beginResize:
            guard let target = event.target, target.outcome == .usable,
                  let frame = target.frame, let windowID = target.windowId else {
                if let diagnostic = event.target?.diagnostic {
                    diagnostics.append(diagnostic)
                }
                disposition = .passThrough
                break
            }
            self.windowID = windowID
            applicationID = target.applicationId
            if configuration.bringToFront {
                if let applicationID {
                    commands.append(ContractCommand(type: .activateApplication, applicationId: applicationID))
                }
                commands.append(ContractCommand(type: .raiseWindow, windowId: windowID))
            }

            let gestureInput: GestureInput
            if intent == .beginMove {
                gestureInput = .beginMove(frame: frame.coreValue, timestamp: event.timestampNanoseconds)
            } else {
                let section = GeometryPolicy.resizeSection(
                    for: event.pointer!,
                    in: frame.coreValue
                )
                gestureInput = .beginResize(
                    frame: frame.coreValue,
                    section: section,
                    timestamp: event.timestampNanoseconds
                )
            }
            state = GestureEngine.reduce(
                state: state,
                input: gestureInput,
                configuration: gestureConfiguration
            ).state

        case .continueMove, .continueResize:
            let delta = event.delta!
            let gestureInput: GestureInput = intent == .continueMove
                ? .moveBy(deltaX: delta.x, deltaY: delta.y, timestamp: event.timestampNanoseconds)
                : .resizeBy(deltaX: delta.x, deltaY: delta.y, timestamp: event.timestampNanoseconds)
            let transition = GestureEngine.reduce(
                state: state,
                input: gestureInput,
                configuration: gestureConfiguration
            )
            state = transition.state
            commands.append(contentsOf: normalizedCommands(transition.commands))

        case .toggleMaximize, .snapByRegion, .endActionClick, .cancelGesture:
            break

        case .endGesture:
            let transition = GestureEngine.reduce(
                state: state,
                input: .end(timestamp: event.timestampNanoseconds),
                configuration: gestureConfiguration
            )
            state = transition.state
            commands.append(contentsOf: normalizedCommands(transition.commands))
        }

        let output = ContractOutput(
            state: normalizedState,
            commands: commands,
            disposition: disposition,
            diagnostics: diagnostics
        )
        if !state.isActive {
            windowID = nil
            applicationID = nil
        }
        return output
    }

    private var gestureConfiguration: GestureConfiguration {
        GestureConfiguration(
            moveThrottleInterval: configuration.moveThrottleNanoseconds,
            resizeThrottleInterval: configuration.resizeThrottleNanoseconds
        )
    }

    private var normalizedState: ContractState {
        guard let context = state.context else {
            return ContractState(kind: .idle, gesture: nil)
        }
        let kind: ContractStateKind
        switch state {
        case .moving:
            kind = .moving
        case .resizing:
            kind = .resizing
        case .idle:
            kind = .idle
        }
        return ContractState(
            kind: kind,
            gesture: ContractGesture(
                windowId: windowID!,
                applicationId: applicationID,
                frame: ContractFrame(context.frame),
                horizontalEdge: context.resizeSection.horizontalEdge,
                verticalEdge: context.resizeSection.verticalEdge,
                lastWriteTimeNanoseconds: context.lastWriteTime
            )
        )
    }

    private func normalizedCommands(_ commands: [GestureCommand]) -> [ContractCommand] {
        commands.map { command in
            switch command {
            case let .setPosition(position):
                return ContractCommand(type: .setPosition, windowId: windowID!, position: position)
            case let .setSize(size):
                return ContractCommand(type: .setSize, windowId: windowID!, size: size)
            }
        }
    }

    private func runLifecycleEvent(_ event: ContractEvent) -> ContractOutput {
        switch event.type {
        case .sessionBecameActive:
            configuration.sessionActive = true
        case .sessionBecameInactive:
            configuration.sessionActive = false
            cancel(at: event.timestampNanoseconds)
        case .overallEnabled:
            configuration.overallEnabled = true
        case .overallDisabled:
            configuration.overallEnabled = false
            cancel(at: event.timestampNanoseconds)
        case .targetInvalidated, .accessibilityTrustLost:
            cancel(at: event.timestampNanoseconds)
        default:
            break
        }
        return ContractOutput(
            state: normalizedState,
            commands: [],
            disposition: .notApplicable,
            diagnostics: []
        )
    }

    private func cancel(at timestamp: UInt64) {
        state = GestureEngine.reduce(
            state: state,
            input: .cancel(timestamp: timestamp),
            configuration: gestureConfiguration
        ).state
        windowID = nil
        applicationID = nil
    }

    private func isLifecycleEvent(_ type: ContractEventType) -> Bool {
        switch type {
        case .sessionBecameActive, .sessionBecameInactive,
             .overallEnabled, .overallDisabled,
             .targetInvalidated, .accessibilityTrustLost:
            return true
        default:
            return false
        }
    }

    private func coreEventType(_ type: ContractEventType) -> InputEventType {
        switch type {
        case .mouseDown:
            return .mouseDown
        case .mouseDragged:
            return .mouseDragged
        case .mouseUp:
            return .mouseUp
        case .tapDisabledByTimeout:
            return .tapDisabledByTimeout
        case .tapDisabledByUserInput:
            return .tapDisabledByUserInput
        default:
            return .unknown
        }
    }
}

final class GestureContractTests: XCTestCase {
    func testEveryGestureContractFixture() throws {
        let fixtures = try loadFixtures()
        XCTAssertFalse(fixtures.isEmpty)
        XCTAssertEqual(Set(fixtures.map(\.id)).count, fixtures.count, "Fixture IDs must be unique")

        for fixture in fixtures {
            XCTAssertEqual(fixture.schemaVersion, 1, "\(fixture.id) has an unsupported schema")
            let runner = SwiftGestureContractRunner(fixture: fixture)
            for (index, step) in fixture.steps.enumerated() {
                let actual = runner.run(step.event)
                let difference = try firstJSONDifference(
                    expected: step.expectedSwiftOutput,
                    actual: actual
                )
                XCTAssertNil(difference, "\(fixture.id) step \(index): \(difference ?? "")")
            }
        }
    }

    private func loadFixtures() throws -> [GestureContractFixture] {
        try loadContractFixtures(
            GestureContractFixture.self,
            directory: "TestContracts/v1/gesture"
        ).sorted { $0.id < $1.id }
    }
}
