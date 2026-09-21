// Smoothing preset coefficients are adapted from LinearMouse under the MIT License.
// Copyright (c) 2021-2026 LinearMouse
// See THIRD_PARTY_NOTICES.md for source and license details.

import Foundation

public enum ScrollDistance: Codable, Equatable, Sendable {
    case automatic
    case lines(Int)
    case pixels(Double)

    private enum CodingKeys: String, CodingKey {
        case mode
        case value
    }

    private enum Mode: String, Codable {
        case automatic
        case lines
        case pixels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Mode.self, forKey: .mode) {
        case .automatic:
            self = .automatic
        case .lines:
            self = .lines(try container.decode(Int.self, forKey: .value))
        case .pixels:
            self = .pixels(try container.decode(Double.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .automatic:
            try container.encode(Mode.automatic, forKey: .mode)
        case let .lines(value):
            try container.encode(Mode.lines, forKey: .mode)
            try container.encode(value, forKey: .value)
        case let .pixels(value):
            try container.encode(Mode.pixels, forKey: .mode)
            try container.encode(value, forKey: .value)
        }
    }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case let .lines(value): "\(value) line\(value == 1 ? "" : "s")"
        case let .pixels(value): "\(value.formatted()) pixels"
        }
    }
}

public enum ScrollSmoothingPreset: String, CaseIterable, Codable, Equatable, Sendable {
    case custom
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case smooth

    public var title: String {
        switch self {
        case .custom: "Custom"
        case .linear: "Linear"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In Out"
        case .smooth: "Smooth"
        }
    }
}

extension ScrollSmoothingPreset {
    struct EngineProfile: Equatable, Sendable {
        var response: Double
        var inputExponent: Double
        var accelerationGain: Double
        var decay: Double
        var velocityScale: Double
    }

    var engineProfile: EngineProfile {
        switch self {
        case .custom:
            EngineProfile(response: 0.64, inputExponent: 1, accelerationGain: 0.10, decay: 0.89, velocityScale: 32)
        case .linear:
            EngineProfile(response: 0.94, inputExponent: 0.96, accelerationGain: 0.04, decay: 0.83, velocityScale: 34)
        case .easeIn:
            EngineProfile(response: 0.34, inputExponent: 1.18, accelerationGain: 0.08, decay: 0.93, velocityScale: 24)
        case .easeOut:
            EngineProfile(response: 0.90, inputExponent: 0.92, accelerationGain: 0.08, decay: 0.84, velocityScale: 34)
        case .easeInOut:
            EngineProfile(response: 0.68, inputExponent: 1.06, accelerationGain: 0.10, decay: 0.89, velocityScale: 31)
        case .smooth:
            EngineProfile(response: 0.80, inputExponent: 0.98, accelerationGain: 0.06, decay: 0.93, velocityScale: 33)
        }
    }
}

public struct ScrollSmoothingSettings: Codable, Equatable, Sendable {
    public var enabled: Bool?
    public var preset: ScrollSmoothingPreset?
    public var response: Double?
    public var speed: Double?
    public var acceleration: Double?
    public var inertia: Double?
    public var bouncing: Bool?

    public init(
        enabled: Bool? = nil,
        preset: ScrollSmoothingPreset? = nil,
        response: Double? = nil,
        speed: Double? = nil,
        acceleration: Double? = nil,
        inertia: Double? = nil,
        bouncing: Bool? = nil
    ) {
        self.enabled = enabled
        self.preset = preset
        self.response = response
        self.speed = speed
        self.acceleration = acceleration
        self.inertia = inertia
        self.bouncing = bouncing
    }

    public mutating func merge(_ other: Self) {
        if let value = other.enabled { enabled = value }
        if let value = other.preset { preset = value }
        if let value = other.response { response = value }
        if let value = other.speed { speed = value }
        if let value = other.acceleration { acceleration = value }
        if let value = other.inertia { inertia = value }
        if let value = other.bouncing { bouncing = value }
    }
}

public struct ScrollAxisSettings: Codable, Equatable, Sendable {
    public var reverse: Bool?
    public var distance: ScrollDistance?
    public var acceleration: Double?
    public var speed: Double?
    public var smoothing: ScrollSmoothingSettings?

    public init(
        reverse: Bool? = nil,
        distance: ScrollDistance? = nil,
        acceleration: Double? = nil,
        speed: Double? = nil,
        smoothing: ScrollSmoothingSettings? = nil
    ) {
        self.reverse = reverse
        self.distance = distance
        self.acceleration = acceleration
        self.speed = speed
        self.smoothing = smoothing
    }

    public mutating func merge(_ other: Self) {
        if let value = other.reverse { reverse = value }
        if let value = other.distance { distance = value }
        if let value = other.acceleration { acceleration = value }
        if let value = other.speed { speed = value }
        if let otherSmoothing = other.smoothing {
            if smoothing == nil {
                smoothing = otherSmoothing
            } else {
                smoothing?.merge(otherSmoothing)
            }
        }
    }
}

public struct ScrollProfileMatch: Codable, Equatable, Sendable {
    public var deviceCategory: PointingDeviceCategory?
    public var deviceKey: String?
    public var deviceDisplayName: String?
    public var applicationBundleIdentifiers: [String]
    public var processNames: [String]
    public var excludedApplicationBundleIdentifiers: [String]
    public var excludedProcessNames: [String]

    public init(
        deviceCategory: PointingDeviceCategory? = nil,
        deviceKey: String? = nil,
        deviceDisplayName: String? = nil,
        applicationBundleIdentifiers: [String] = [],
        processNames: [String] = [],
        excludedApplicationBundleIdentifiers: [String] = [],
        excludedProcessNames: [String] = []
    ) {
        self.deviceCategory = deviceCategory
        self.deviceKey = deviceKey
        self.deviceDisplayName = deviceDisplayName
        self.applicationBundleIdentifiers = applicationBundleIdentifiers
        self.processNames = processNames
        self.excludedApplicationBundleIdentifiers = excludedApplicationBundleIdentifiers
        self.excludedProcessNames = excludedProcessNames
    }

    private enum CodingKeys: String, CodingKey {
        case deviceCategory
        case deviceKey
        case deviceDisplayName
        case applicationBundleIdentifiers
        case processNames
        case excludedApplicationBundleIdentifiers
        case excludedProcessNames
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceCategory = try container.decodeIfPresent(
            PointingDeviceCategory.self,
            forKey: .deviceCategory
        )
        deviceKey = try container.decodeIfPresent(String.self, forKey: .deviceKey)
        deviceDisplayName = try container.decodeIfPresent(String.self, forKey: .deviceDisplayName)
        applicationBundleIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .applicationBundleIdentifiers
        ) ?? []
        processNames = try container.decodeIfPresent(
            [String].self,
            forKey: .processNames
        ) ?? []
        excludedApplicationBundleIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .excludedApplicationBundleIdentifiers
        ) ?? []
        excludedProcessNames = try container.decodeIfPresent(
            [String].self,
            forKey: .excludedProcessNames
        ) ?? []
    }

    public func matches(
        deviceKey candidateDeviceKey: String?,
        deviceCategory candidateCategory: PointingDeviceCategory,
        applicationBundleIdentifier: String?,
        processName: String?
    ) -> Bool {
        if let deviceCategory, deviceCategory != candidateCategory {
            return false
        }
        if let deviceKey, deviceKey != candidateDeviceKey {
            return false
        }
        if contains(
            applicationBundleIdentifier,
            in: excludedApplicationBundleIdentifiers
        ) || contains(processName, in: excludedProcessNames) {
            return false
        }

        let hasApplicationCondition = !applicationBundleIdentifiers.isEmpty || !processNames.isEmpty
        guard hasApplicationCondition else { return true }

        return contains(applicationBundleIdentifier, in: applicationBundleIdentifiers)
            || contains(processName, in: processNames)
    }

    private func contains(_ candidate: String?, in values: [String]) -> Bool {
        guard let candidate else { return false }
        return values.contains {
            $0.caseInsensitiveCompare(candidate) == .orderedSame
        }
    }
}

public struct ScrollProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var match: ScrollProfileMatch
    public var vertical: ScrollAxisSettings
    public var horizontal: ScrollAxisSettings

    public init(
        id: String = UUID().uuidString,
        name: String,
        isEnabled: Bool = true,
        match: ScrollProfileMatch = ScrollProfileMatch(),
        vertical: ScrollAxisSettings = ScrollAxisSettings(),
        horizontal: ScrollAxisSettings = ScrollAxisSettings()
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.match = match
        self.vertical = vertical
        self.horizontal = horizontal
    }
}

public enum PointingDeviceBatteryDisplayMode: String, CaseIterable, Codable, Equatable, Sendable {
    case never
    case belowTwentyPercent
    case always

    public var title: String {
        switch self {
        case .never: "Never"
        case .belowTwentyPercent: "Below 20%"
        case .always: "Always"
        }
    }

    public func shows(level: Int) -> Bool {
        switch self {
        case .never: false
        case .belowTwentyPercent: level < 20
        case .always: true
        }
    }
}

public struct EffectiveScrollSmoothingSettings: Equatable, Sendable {
    public var preset: ScrollSmoothingPreset
    public var response: Double
    public var speed: Double
    public var acceleration: Double
    public var inertia: Double
    public var bouncing: Bool

    public init(
        preset: ScrollSmoothingPreset,
        response: Double,
        speed: Double,
        acceleration: Double,
        inertia: Double,
        bouncing: Bool
    ) {
        self.preset = preset
        self.response = response
        self.speed = speed
        self.acceleration = acceleration
        self.inertia = inertia
        self.bouncing = bouncing
    }
}

public struct EffectiveScrollAxisSettings: Equatable, Sendable {
    public var reverse: Bool
    public var distance: ScrollDistance
    public var acceleration: Double
    public var speed: Double
    public var smoothing: EffectiveScrollSmoothingSettings?

    public init(
        reverse: Bool,
        distance: ScrollDistance,
        acceleration: Double,
        speed: Double,
        smoothing: EffectiveScrollSmoothingSettings?
    ) {
        self.reverse = reverse
        self.distance = distance
        self.acceleration = acceleration
        self.speed = speed
        self.smoothing = smoothing
    }

    public static let passthrough = EffectiveScrollAxisSettings(
        reverse: false,
        distance: .automatic,
        acceleration: 1,
        speed: 0,
        smoothing: nil
    )
}

public struct EffectiveScrollSettings: Equatable, Sendable {
    public var vertical: EffectiveScrollAxisSettings
    public var horizontal: EffectiveScrollAxisSettings

    public init(
        horizontal: EffectiveScrollAxisSettings,
        vertical: EffectiveScrollAxisSettings
    ) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    public var requiresTransformation: Bool {
        let verticalRequiresTransformation = vertical.reverse
            || vertical.distance != .automatic
            || vertical.acceleration != 1
            || vertical.speed != 0
            || vertical.smoothing != nil
        if verticalRequiresTransformation {
            return true
        }

        return horizontal.reverse
            || horizontal.distance != .automatic
            || horizontal.acceleration != 1
            || horizontal.speed != 0
            || horizontal.smoothing != nil
    }
}

public enum ScrollProfileResolver {
    public static func resolve(
        input: InputCustomizationSettings,
        deviceKey: String?,
        deviceCategory: PointingDeviceCategory,
        applicationBundleIdentifier: String?,
        processName: String?
    ) -> EffectiveScrollSettings {
        let categoryReverse = input.reverseScrolling(
            forDeviceKey: deviceKey,
            category: deviceCategory
        )
        var vertical = ScrollAxisSettings(reverse: categoryReverse)
        var horizontal = ScrollAxisSettings(reverse: categoryReverse)

        for profile in input.scrollProfiles where profile.isEnabled
            && profile.match.matches(
                deviceKey: deviceKey,
                deviceCategory: deviceCategory,
                applicationBundleIdentifier: applicationBundleIdentifier,
                processName: processName
            ) {
            vertical.merge(profile.vertical)
            horizontal.merge(profile.horizontal)
        }

        return EffectiveScrollSettings(
            horizontal: effective(horizontal),
            vertical: effective(vertical)
        )
    }

    private static func effective(_ settings: ScrollAxisSettings) -> EffectiveScrollAxisSettings {
        let smoothing: EffectiveScrollSmoothingSettings?
        if settings.smoothing?.enabled == true {
            let values = settings.smoothing ?? ScrollSmoothingSettings()
            smoothing = EffectiveScrollSmoothingSettings(
                preset: values.preset ?? .easeInOut,
                response: clamp(values.response ?? 0.45, to: 0 ... 2),
                speed: clamp(values.speed ?? 1, to: 0 ... 8),
                acceleration: clamp(values.acceleration ?? 1.2, to: 0 ... 8),
                inertia: clamp(values.inertia ?? 0.65, to: 0 ... 8),
                bouncing: values.bouncing ?? true
            )
        } else {
            smoothing = nil
        }
        return EffectiveScrollAxisSettings(
            reverse: settings.reverse ?? false,
            distance: validated(settings.distance ?? .automatic),
            acceleration: clamp(settings.acceleration ?? 1, to: 0 ... 8),
            speed: clamp(settings.speed ?? 0, to: -8 ... 8),
            smoothing: smoothing
        )
    }

    private static func validated(_ distance: ScrollDistance) -> ScrollDistance {
        switch distance {
        case .automatic:
            return .automatic
        case let .lines(value):
            return .lines(min(100, max(1, value)))
        case let .pixels(value):
            return .pixels(min(1_000, max(0.1, value)))
        }
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
