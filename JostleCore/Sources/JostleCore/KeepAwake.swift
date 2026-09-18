import Foundation

public enum KeepAwakeDurationPreset: String, CaseIterable, Codable, Sendable {
    case indefinitely
    case tenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case eightHours
    case twelveHours

    public var duration: KeepAwakeDuration {
        switch self {
        case .indefinitely:
            return .indefinitely
        case .tenMinutes:
            return .seconds(10 * 60)
        case .thirtyMinutes:
            return .seconds(30 * 60)
        case .oneHour:
            return .seconds(60 * 60)
        case .twoHours:
            return .seconds(2 * 60 * 60)
        case .fourHours:
            return .seconds(4 * 60 * 60)
        case .eightHours:
            return .seconds(8 * 60 * 60)
        case .twelveHours:
            return .seconds(12 * 60 * 60)
        }
    }

    public var title: String {
        switch self {
        case .indefinitely: "Indefinitely"
        case .tenMinutes: "10 Minutes"
        case .thirtyMinutes: "30 Minutes"
        case .oneHour: "1 Hour"
        case .twoHours: "2 Hours"
        case .fourHours: "4 Hours"
        case .eightHours: "8 Hours"
        case .twelveHours: "12 Hours"
        }
    }
}

public enum KeepAwakeDuration: Equatable, Sendable {
    case indefinitely
    case seconds(TimeInterval)

    public static let maximumFiniteSeconds = Double(Int64.max) / 1_000_000_000

    public var seconds: TimeInterval? {
        switch self {
        case .indefinitely:
            nil
        case let .seconds(seconds):
            seconds
        }
    }

    public var isValid: Bool {
        guard let seconds else { return true }
        return seconds.isFinite
            && seconds > 0
            && seconds <= Self.maximumFiniteSeconds
    }
}

public enum KeepAwakeIndicatorStyle: String, CaseIterable, Codable, Sendable {
    case normal
    case badgeGreen
    case badgeBlue
    case coloredGreen
    case coloredBlue

    public var title: String {
        switch self {
        case .normal: "Normal"
        case .badgeGreen: "Green Cup"
        case .badgeBlue: "Blue Cup"
        case .coloredGreen: "Green Icon"
        case .coloredBlue: "Blue Icon"
        }
    }
}

public struct GlobalShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: Set<Modifier>

    public init(keyCode: UInt32, modifiers: Set<Modifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var isValid: Bool {
        !modifiers.isEmpty
    }
}

public enum KeepAwakeCommand: Equatable, Sendable {
    /// A nil duration means the configured default duration.
    case activate(KeepAwakeDuration?)
    case deactivate
    /// A nil duration means the configured default duration if toggling on.
    case toggle(KeepAwakeDuration?)
}

public enum KeepAwakeURLCommandError: LocalizedError, Equatable {
    case invalidScheme
    case unsupportedCommand(String)
    case unsupportedParameter(String)
    case duplicateParameter(String)
    case invalidDuration

    public var errorDescription: String? {
        switch self {
        case .invalidScheme:
            "The URL must use the jostle scheme."
        case let .unsupportedCommand(command):
            "Unsupported Jostle command: \(command)."
        case let .unsupportedParameter(parameter):
            "Unsupported Jostle parameter: \(parameter)."
        case let .duplicateParameter(parameter):
            "The Jostle parameter \(parameter) may only be supplied once."
        case .invalidDuration:
            "The keep-awake duration must be a positive value within the supported range."
        }
    }
}

public enum KeepAwakeURLCommandParser {
    public static func parse(_ url: URL) throws -> KeepAwakeCommand {
        guard url.scheme?.lowercased() == "jostle" else {
            throw KeepAwakeURLCommandError.invalidScheme
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw KeepAwakeURLCommandError.unsupportedCommand("")
        }
        let command = commandName(from: url, components: components)
        let duration = try duration(from: components.queryItems ?? [])

        switch command {
        case "activate":
            return .activate(duration)
        case "deactivate":
            guard duration == nil else {
                throw KeepAwakeURLCommandError.unsupportedParameter("duration")
            }
            return .deactivate
        case "toggle":
            return .toggle(duration)
        default:
            throw KeepAwakeURLCommandError.unsupportedCommand(command)
        }
    }

    private static func commandName(from url: URL, components: URLComponents) -> String {
        if let host = components.host, !host.isEmpty {
            return host.lowercased()
        }
        if !components.path.isEmpty {
            return components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
        }

        let absolute = url.absoluteString
        guard let colon = absolute.firstIndex(of: ":") else { return "" }
        let suffix = absolute[absolute.index(after: colon)...]
        let command = suffix.prefix { $0 != "?" && $0 != "#" }
        return command.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .removingPercentEncoding?
            .lowercased() ?? ""
    }

    private static func duration(from items: [URLQueryItem]) throws -> KeepAwakeDuration? {
        var values: [String: Double] = [:]
        for item in items {
            let name = item.name.lowercased()
            guard name == "hours" || name == "minutes" else {
                throw KeepAwakeURLCommandError.unsupportedParameter(item.name)
            }
            guard values[name] == nil else {
                throw KeepAwakeURLCommandError.duplicateParameter(item.name)
            }
            guard let value = item.value,
                  let number = Double(value),
                  number.isFinite,
                  number >= 0 else {
                throw KeepAwakeURLCommandError.invalidDuration
            }
            values[name] = number
        }

        guard !values.isEmpty else { return nil }
        let seconds = (values["hours"] ?? 0) * 3_600 + (values["minutes"] ?? 0) * 60
        let duration = KeepAwakeDuration.seconds(seconds)
        guard duration.isValid else {
            throw KeepAwakeURLCommandError.invalidDuration
        }
        return duration
    }
}
