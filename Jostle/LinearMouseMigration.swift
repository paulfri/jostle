import Foundation
import JostleCore

/// Imports the supported subset of an existing LinearMouse configuration once.
/// Unsupported vendor controls and disabled actions are intentionally ignored.
enum LinearMouseMigration {
    static let markerKey = "Jostle.didImportLinearMouse.v1"
    static let defaultConfigurationURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/linearmouse/linearmouse.json")

    static func migrateIfNeeded(
        settingsStore: SettingsStore,
        pointingDevices: [PointingDeviceInfo],
        userDefaults: UserDefaults = .standard,
        configurationURL: URL = defaultConfigurationURL
    ) {
        guard !userDefaults.bool(forKey: markerKey),
              settingsStore.settings.inputCustomization.scrollProfiles.isEmpty,
              let data = try? Data(contentsOf: configurationURL),
              let imported = try? importedInput(
                  from: data,
                  pointingDevices: pointingDevices
              ) else {
            return
        }
        if imported.requiresDeviceInventory,
           pointingDevices.isEmpty || imported.hasUnresolvedExactDevice {
            return
        }

        settingsStore.update { settings in
            var input = settings.inputCustomization
            input.schemaVersion = InputCustomizationSettings.defaults.schemaVersion
            input.isEnabled = true
            input.universalBackForward = input.universalBackForward
                || imported.settings.universalBackForward
            input.scrollProfiles = imported.settings.scrollProfiles
            input.batteryDisplayMode = .always
            settings.inputCustomization = input
        }
        userDefaults.set(true, forKey: markerKey)
    }

    struct ImportResult {
        var settings: InputCustomizationSettings
        var requiresDeviceInventory: Bool
        var hasUnresolvedExactDevice: Bool
    }

    static func importedInput(
        from data: Data,
        pointingDevices: [PointingDeviceInfo]
    ) throws -> ImportResult {
        guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemes = document["schemes"] as? [[String: Any]] else {
            throw MigrationError.invalidConfiguration
        }

        var input = InputCustomizationSettings.defaults
        var profiles: [ScrollProfile] = []
        var requiresDeviceInventory = false
        var hasUnresolvedExactDevice = false

        for (offset, scheme) in schemes.enumerated() {
            if let buttons = scheme["buttons"] as? [String: Any],
               boolean(buttons["universalBackForward"]) == true {
                input.universalBackForward = true
            }
            guard let scrolling = scheme["scrolling"] as? [String: Any] else {
                continue
            }
            let axisSettings = parseScrolling(scrolling)
            guard axisSettings.vertical.hasValues || axisSettings.horizontal.hasValues else {
                continue
            }

            let matches = parseMatches(
                scheme["if"],
                pointingDevices: pointingDevices,
                requiresDeviceInventory: &requiresDeviceInventory,
                hasUnresolvedExactDevice: &hasUnresolvedExactDevice
            )
            for (matchOffset, match) in matches.enumerated() {
                profiles.append(ScrollProfile(
                    name: profileName(
                        schemeNumber: offset + 1,
                        alternativeNumber: matches.count == 1 ? nil : matchOffset + 1,
                        match: match
                    ),
                    match: match,
                    vertical: axisSettings.vertical,
                    horizontal: axisSettings.horizontal
                ))
            }
        }

        input.scrollProfiles = profiles
        return ImportResult(
            settings: input,
            requiresDeviceInventory: requiresDeviceInventory,
            hasUnresolvedExactDevice: hasUnresolvedExactDevice
        )
    }

    private struct ParsedAxes {
        var vertical = ScrollAxisSettings()
        var horizontal = ScrollAxisSettings()
    }

    private struct Directional<Value> {
        var vertical: Value?
        var horizontal: Value?
    }

    private static func parseScrolling(_ scrolling: [String: Any]) -> ParsedAxes {
        var result = ParsedAxes()

        if let raw = scrolling["reverse"] {
            let values = directional(raw, parse: boolean)
            result.vertical.reverse = values.vertical
            result.horizontal.reverse = values.horizontal
        }
        if let raw = scrolling["distance"] {
            let values = directional(raw, parse: distance)
            result.vertical.distance = values.vertical
            result.horizontal.distance = values.horizontal
        }
        if let raw = scrolling["acceleration"] {
            let values = directional(raw, parse: number)
            result.vertical.acceleration = values.vertical
            result.horizontal.acceleration = values.horizontal
        }
        if let raw = scrolling["speed"] {
            let values = directional(raw, parse: number)
            result.vertical.speed = values.vertical
            result.horizontal.speed = values.horizontal
        }
        if let raw = scrolling["smoothed"] {
            let values = directional(raw, parse: smoothing)
            result.vertical.smoothing = values.vertical
            result.horizontal.smoothing = values.horizontal
        }
        return result
    }

    private static func directional<Value>(
        _ raw: Any,
        parse: (Any?) -> Value?
    ) -> Directional<Value> {
        if let dictionary = raw as? [String: Any],
           dictionary.keys.contains("vertical") || dictionary.keys.contains("horizontal") {
            return Directional(
                vertical: parse(dictionary["vertical"]),
                horizontal: parse(dictionary["horizontal"])
            )
        }
        let value = parse(raw)
        return Directional(vertical: value, horizontal: value)
    }

    private static func smoothing(_ raw: Any?) -> ScrollSmoothingSettings? {
        if let enabled = boolean(raw) {
            return ScrollSmoothingSettings(enabled: enabled)
        }
        guard let dictionary = raw as? [String: Any] else { return nil }
        return ScrollSmoothingSettings(
            enabled: boolean(dictionary["enabled"]) ?? true,
            preset: (dictionary["preset"] as? String).flatMap(ScrollSmoothingPreset.init(rawValue:)),
            response: number(dictionary["response"]),
            speed: number(dictionary["speed"]),
            acceleration: number(dictionary["acceleration"]),
            inertia: number(dictionary["inertia"]),
            bouncing: boolean(dictionary["bouncing"])
        )
    }

    private static func distance(_ raw: Any?) -> ScrollDistance? {
        if let value = raw as? String, value.caseInsensitiveCompare("auto") == .orderedSame {
            return .automatic
        }
        guard let value = number(raw) else { return nil }
        return .lines(max(1, Int(value.rounded())))
    }

    private static func number(_ raw: Any?) -> Double? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        return number.doubleValue
    }

    private static func boolean(_ raw: Any?) -> Bool? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return nil
        }
        return number.boolValue
    }

    private static func parseMatches(
        _ raw: Any?,
        pointingDevices: [PointingDeviceInfo],
        requiresDeviceInventory: inout Bool,
        hasUnresolvedExactDevice: inout Bool
    ) -> [ScrollProfileMatch] {
        let conditions: [[String: Any]]
        if let array = raw as? [[String: Any]] {
            conditions = array
        } else if let condition = raw as? [String: Any] {
            conditions = [condition]
        } else {
            conditions = [[:]]
        }

        let parsed = conditions.compactMap { condition -> ScrollProfileMatch? in
            var match = ScrollProfileMatch()
            if let app = condition["app"] as? String {
                match.applicationBundleIdentifiers = [app]
            }
            if let process = condition["processName"] as? String {
                match.processNames = [process]
            }
            if let device = condition["device"] as? [String: Any] {
                if let category = device["category"] as? String {
                    match.deviceCategory = PointingDeviceCategory(rawValue: category)
                }
                let specifiesExactDevice = device["productName"] != nil
                    || device["vendorID"] != nil
                    || device["productID"] != nil
                    || device["serialNumber"] != nil
                if specifiesExactDevice {
                    requiresDeviceInventory = true
                    guard let pointingDevice = pointingDevices.first(where: {
                        matchesExactDevice($0, condition: device)
                    }) else {
                        hasUnresolvedExactDevice = true
                        return nil
                    }
                    match.deviceKey = pointingDevice.id
                    match.deviceDisplayName = pointingDevice.displayName
                    match.deviceCategory = pointingDevice.category
                }
            }
            return match
        }

        guard let first = parsed.first else { return [] }
        let sharesDeviceTarget = parsed.allSatisfy {
            $0.deviceCategory == first.deviceCategory && $0.deviceKey == first.deviceKey
        }
        if sharesDeviceTarget {
            return [ScrollProfileMatch(
                deviceCategory: first.deviceCategory,
                deviceKey: first.deviceKey,
                deviceDisplayName: first.deviceDisplayName,
                applicationBundleIdentifiers: parsed.flatMap(\.applicationBundleIdentifiers),
                processNames: parsed.flatMap(\.processNames)
            )]
        }
        return parsed
    }

    private static func matchesExactDevice(
        _ pointingDevice: PointingDeviceInfo,
        condition: [String: Any]
    ) -> Bool {
        if let productName = condition["productName"] as? String,
           pointingDevice.displayName.caseInsensitiveCompare(productName) != .orderedSame {
            return false
        }
        if condition["vendorID"] != nil {
            guard let vendorID = hardwareIdentifier(condition["vendorID"]),
                  pointingDevice.vendorID == vendorID else {
                return false
            }
        }
        if condition["productID"] != nil {
            guard let productID = hardwareIdentifier(condition["productID"]),
                  pointingDevice.productID == productID else {
                return false
            }
        }
        if let serialNumber = condition["serialNumber"] as? String,
           pointingDevice.serialNumber?.caseInsensitiveCompare(serialNumber) != .orderedSame {
            return false
        }
        return true
    }

    private static func hardwareIdentifier(_ raw: Any?) -> Int? {
        if let number = raw as? NSNumber,
           CFGetTypeID(number) != CFBooleanGetTypeID() {
            return number.intValue
        }
        guard let string = raw as? String else { return nil }
        if string.lowercased().hasPrefix("0x") {
            return Int(string.dropFirst(2), radix: 16)
        }
        return Int(string)
    }

    private static func profileName(
        schemeNumber: Int,
        alternativeNumber: Int?,
        match: ScrollProfileMatch
    ) -> String {
        let suffix: String
        if !match.processNames.isEmpty {
            suffix = match.processNames.joined(separator: ", ")
        } else if match.deviceKey != nil {
            suffix = "Exact Device"
        } else if !match.applicationBundleIdentifiers.isEmpty {
            suffix = "Applications"
        } else if let category = match.deviceCategory {
            suffix = category.title
        } else {
            suffix = "All Input"
        }
        let number = alternativeNumber.map { "\(schemeNumber).\($0)" } ?? "\(schemeNumber)"
        return "LinearMouse \(number) — \(suffix)"
    }

    private enum MigrationError: Error {
        case invalidConfiguration
    }
}

private extension ScrollAxisSettings {
    var hasValues: Bool {
        reverse != nil
            || distance != nil
            || acceleration != nil
            || speed != nil
            || smoothing != nil
    }
}
