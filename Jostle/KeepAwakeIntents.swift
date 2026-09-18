import AppIntents
import AppKit
import Foundation
import JostleCore

private enum KeepAwakeIntentAction: String, AppEnum {
    case toggle
    case turnOn
    case turnOff

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .toggle: "Toggle",
        .turnOn: "Turn On",
        .turnOff: "Turn Off"
    ]
}

private enum KeepAwakeIntentDurationType: String, AppEnum {
    case defaultDuration
    case indefinitely
    case custom

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Duration Type")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .defaultDuration: "Default Duration",
        .indefinitely: "Indefinitely",
        .custom: "Custom"
    ]
}

struct SetKeepAwakeStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Keep Awake State"
    static let description = IntentDescription("Turns Jostle Keep Awake on or off, or toggles its current state.")
    static let openAppWhenRun = false

    @Parameter(title: "Action", default: .toggle)
    private var action: KeepAwakeIntentAction

    @Parameter(title: "Duration", default: .defaultDuration)
    private var durationType: KeepAwakeIntentDurationType

    @Parameter(title: "Custom Duration (in seconds)")
    private var customDuration: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) Keep Awake") {
            \.$durationType
            \.$customDuration
        }
    }

    func perform() async throws -> some IntentResult {
        let duration = try requestedDuration()
        try await MainActor.run {
            let controller = try Self.controller()
            switch action {
            case .toggle:
                controller.perform(.toggle(duration))
            case .turnOn:
                controller.perform(.activate(duration))
            case .turnOff:
                controller.perform(.deactivate)
            }
        }
        return .result()
    }

    private func requestedDuration() throws -> KeepAwakeDuration? {
        guard action != .turnOff else { return nil }
        switch durationType {
        case .defaultDuration:
            return nil
        case .indefinitely:
            return .indefinitely
        case .custom:
            guard let customDuration else {
                throw KeepAwakeIntentError.invalidDuration
            }
            let duration = KeepAwakeDuration.seconds(customDuration)
            guard duration.isValid else {
                throw KeepAwakeIntentError.invalidDuration
            }
            return duration
        }
    }

    @MainActor
    private static func controller() throws -> KeepAwakeController {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else {
            throw KeepAwakeIntentError.appUnavailable
        }
        return delegate.keepAwakeController
    }
}

struct GetKeepAwakeStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Keep Awake State"
    static let description = IntentDescription("Returns whether Jostle Keep Awake is enabled.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let enabled = try await MainActor.run {
            guard let delegate = NSApplication.shared.delegate as? AppDelegate else {
                throw KeepAwakeIntentError.appUnavailable
            }
            return delegate.keepAwakeController.isEnabled
        }
        return .result(value: enabled)
    }
}

private enum KeepAwakeIntentError: LocalizedError {
    case invalidDuration
    case appUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            "The custom duration must be greater than zero and within the supported range."
        case .appUnavailable:
            "Jostle is not ready to handle this action."
        }
    }
}
