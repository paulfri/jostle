import JostleCore
import SwiftUI

struct ScrollProfileEditor: View {
    @Binding var profile: ScrollProfile
    let devices: [PointingDeviceInfo]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Toggle("", isOn: $profile.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("Profile name", text: $profile.name)
                    .textFieldStyle(.plain)
                Text(matchSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button { onMoveUp() } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(!canMoveUp)
                .buttonStyle(.borderless)
                .help("Move profile earlier")
                Button { onMoveDown() } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(!canMoveDown)
                .buttonStyle(.borderless)
                .help("Move profile later; later matching profiles take priority")
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .help(isExpanded ? "Hide profile settings" : "Edit profile")
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete profile")
            }

            if isExpanded {
                Divider()
                matchEditor
                Divider()
                HStack(alignment: .top, spacing: 18) {
                    ScrollAxisProfileEditor(title: "Vertical", settings: $profile.vertical)
                    Divider()
                    ScrollAxisProfileEditor(title: "Horizontal", settings: $profile.horizontal)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var matchEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                Picker("Device type", selection: deviceCategoryBinding) {
                    Text("Any device type").tag("any")
                    Text("Mouse").tag(PointingDeviceCategory.mouse.rawValue)
                    Text("Trackpad").tag(PointingDeviceCategory.trackpad.rawValue)
                }
                .frame(width: 190)

                Picker("Exact device", selection: deviceKeyBinding) {
                    Text("Any pointing device").tag("")
                    ForEach(devices) { device in
                        Text(device.displayName).tag(device.id)
                    }
                    if let deviceKey = profile.match.deviceKey,
                       !devices.contains(where: { $0.id == deviceKey }) {
                        Text("\(profile.match.deviceDisplayName ?? "Pointing Device") — Disconnected")
                            .tag(deviceKey)
                    }
                }
                .frame(width: 250)
            }
            Text("Includes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(
                "Application bundle IDs (comma separated)",
                text: applicationIdentifiersBinding
            )
            TextField("Process names (comma separated)", text: processNamesBinding)
            Text("Excludes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(
                "Excluded application bundle IDs (comma separated)",
                text: excludedApplicationIdentifiersBinding
            )
            TextField(
                "Excluded process names (comma separated)",
                text: excludedProcessNamesBinding
            )
            Text("Leave Includes empty to match every application. Excludes skip this profile; base scrolling direction and other matching profiles still apply.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var matchSummary: String {
        var parts: [String] = []
        if let category = profile.match.deviceCategory { parts.append(category.title) }
        if profile.match.deviceKey != nil { parts.append("exact device") }
        if !profile.match.applicationBundleIdentifiers.isEmpty {
            parts.append("\(profile.match.applicationBundleIdentifiers.count) app\(profile.match.applicationBundleIdentifiers.count == 1 ? "" : "s")")
        }
        if !profile.match.processNames.isEmpty {
            parts.append("\(profile.match.processNames.count) process\(profile.match.processNames.count == 1 ? "" : "es")")
        }
        if parts.isEmpty {
            parts.append("All input")
        }
        if !profile.match.excludedApplicationBundleIdentifiers.isEmpty {
            let count = profile.match.excludedApplicationBundleIdentifiers.count
            parts.append("except \(count) app\(count == 1 ? "" : "s")")
        }
        if !profile.match.excludedProcessNames.isEmpty {
            let count = profile.match.excludedProcessNames.count
            parts.append("except \(count) process\(count == 1 ? "" : "es")")
        }
        return parts.joined(separator: " · ")
    }

    private var deviceCategoryBinding: Binding<String> {
        Binding(
            get: { profile.match.deviceCategory?.rawValue ?? "any" },
            set: { value in
                profile.match.deviceCategory = value == "any"
                    ? nil
                    : PointingDeviceCategory(rawValue: value)
            }
        )
    }

    private var deviceKeyBinding: Binding<String> {
        Binding(
            get: { profile.match.deviceKey ?? "" },
            set: { value in
                profile.match.deviceKey = value.isEmpty ? nil : value
                profile.match.deviceDisplayName = value.isEmpty
                    ? nil
                    : devices.first(where: { $0.id == value })?.displayName
                        ?? profile.match.deviceDisplayName
            }
        )
    }

    private var applicationIdentifiersBinding: Binding<String> {
        listBinding(
            get: { profile.match.applicationBundleIdentifiers },
            set: { profile.match.applicationBundleIdentifiers = $0 }
        )
    }

    private var processNamesBinding: Binding<String> {
        listBinding(
            get: { profile.match.processNames },
            set: { profile.match.processNames = $0 }
        )
    }

    private var excludedApplicationIdentifiersBinding: Binding<String> {
        listBinding(
            get: { profile.match.excludedApplicationBundleIdentifiers },
            set: { profile.match.excludedApplicationBundleIdentifiers = $0 }
        )
    }

    private var excludedProcessNamesBinding: Binding<String> {
        listBinding(
            get: { profile.match.excludedProcessNames },
            set: { profile.match.excludedProcessNames = $0 }
        )
    }

    private func listBinding(
        get: @escaping () -> [String],
        set: @escaping ([String]) -> Void
    ) -> Binding<String> {
        Binding(
            get: { get().joined(separator: ", ") },
            set: { value in
                set(value.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty })
            }
        )
    }
}

private struct ScrollAxisProfileEditor: View {
    let title: String
    @Binding var settings: ScrollAxisSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Picker("Direction", selection: directionBinding) {
                Text("Inherit").tag(OptionalBoolean.inherit)
                Text("Standard").tag(OptionalBoolean.off)
                Text("Reverse").tag(OptionalBoolean.on)
            }

            HStack {
                Picker("Distance", selection: distanceModeBinding) {
                    Text("Inherit").tag(DistanceMode.inherit)
                    Text("Automatic").tag(DistanceMode.automatic)
                    Text("Lines").tag(DistanceMode.lines)
                    Text("Pixels").tag(DistanceMode.pixels)
                }
                if distanceModeBinding.wrappedValue == .lines {
                    TextField("Lines", value: lineDistanceBinding, format: .number)
                        .frame(width: 54)
                } else if distanceModeBinding.wrappedValue == .pixels {
                    TextField("Pixels", value: pixelDistanceBinding, format: .number)
                        .frame(width: 62)
                }
            }

            optionalValueRow(
                title: "Acceleration",
                value: accelerationBinding,
                enabled: accelerationEnabledBinding,
                range: 0 ... 8
            )
            optionalValueRow(
                title: "Speed",
                value: speedBinding,
                enabled: speedEnabledBinding,
                range: -8 ... 8
            )

            Picker("Smoothing", selection: smoothingEnabledBinding) {
                Text("Inherit").tag(OptionalBoolean.inherit)
                Text("Off").tag(OptionalBoolean.off)
                Text("On").tag(OptionalBoolean.on)
            }

            if settings.smoothing?.enabled == true {
                Picker("Curve", selection: smoothingPresetBinding) {
                    ForEach(ScrollSmoothingPreset.allCases, id: \.self) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                smoothingValueRow(title: "Response", value: responseBinding, range: 0 ... 2)
                smoothingValueRow(title: "Speed", value: smoothingSpeedBinding, range: 0 ... 8)
                smoothingValueRow(
                    title: "Acceleration",
                    value: smoothingAccelerationBinding,
                    range: 0 ... 8
                )
                smoothingValueRow(title: "Inertia", value: inertiaBinding, range: 0 ... 8)
                Toggle("Bouncing", isOn: bouncingBinding)
                    .toggleStyle(.checkbox)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionalValueRow(
        title: String,
        value: Binding<Double>,
        enabled: Binding<Bool>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: enabled)
                .toggleStyle(.checkbox)
            HStack {
                Slider(value: value, in: range)
                    .disabled(!enabled.wrappedValue)
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private func smoothingValueRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Slider(value: value, in: range)
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var directionBinding: Binding<OptionalBoolean> {
        Binding(
            get: { OptionalBoolean(settings.reverse) },
            set: { settings.reverse = $0.value }
        )
    }

    private var distanceModeBinding: Binding<DistanceMode> {
        Binding(
            get: { DistanceMode(settings.distance) },
            set: { mode in
                switch mode {
                case .inherit: settings.distance = nil
                case .automatic: settings.distance = .automatic
                case .lines: settings.distance = .lines(1)
                case .pixels: settings.distance = .pixels(10)
                }
            }
        )
    }

    private var lineDistanceBinding: Binding<Int> {
        Binding(
            get: {
                if case let .lines(value) = settings.distance { return value }
                return 1
            },
            set: { settings.distance = .lines(min(100, max(1, $0))) }
        )
    }

    private var pixelDistanceBinding: Binding<Double> {
        Binding(
            get: {
                if case let .pixels(value) = settings.distance { return value }
                return 10
            },
            set: { settings.distance = .pixels(min(1_000, max(0.1, $0))) }
        )
    }

    private var accelerationEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.acceleration != nil },
            set: { settings.acceleration = $0 ? (settings.acceleration ?? 1) : nil }
        )
    }

    private var accelerationBinding: Binding<Double> {
        Binding(
            get: { settings.acceleration ?? 1 },
            set: { settings.acceleration = $0 }
        )
    }

    private var speedEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.speed != nil },
            set: { settings.speed = $0 ? (settings.speed ?? 0) : nil }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { settings.speed ?? 0 },
            set: { settings.speed = $0 }
        )
    }

    private var smoothingEnabledBinding: Binding<OptionalBoolean> {
        Binding(
            get: { OptionalBoolean(settings.smoothing?.enabled) },
            set: { choice in
                guard let value = choice.value else {
                    settings.smoothing = nil
                    return
                }
                if settings.smoothing == nil {
                    settings.smoothing = ScrollSmoothingSettings()
                }
                settings.smoothing?.enabled = value
            }
        )
    }

    private var smoothingPresetBinding: Binding<ScrollSmoothingPreset> {
        Binding(
            get: { settings.smoothing?.preset ?? .easeInOut },
            set: { settings.smoothing?.preset = $0 }
        )
    }

    private var responseBinding: Binding<Double> {
        smoothingValue(\.response, default: 0.45)
    }

    private var smoothingSpeedBinding: Binding<Double> {
        smoothingValue(\.speed, default: 1)
    }

    private var smoothingAccelerationBinding: Binding<Double> {
        smoothingValue(\.acceleration, default: 1.2)
    }

    private var inertiaBinding: Binding<Double> {
        smoothingValue(\.inertia, default: 0.65)
    }

    private var bouncingBinding: Binding<Bool> {
        Binding(
            get: { settings.smoothing?.bouncing ?? true },
            set: { settings.smoothing?.bouncing = $0 }
        )
    }

    private func smoothingValue(
        _ keyPath: WritableKeyPath<ScrollSmoothingSettings, Double?>,
        default defaultValue: Double
    ) -> Binding<Double> {
        Binding(
            get: { settings.smoothing?[keyPath: keyPath] ?? defaultValue },
            set: { settings.smoothing?[keyPath: keyPath] = $0 }
        )
    }
}

private enum OptionalBoolean: String, Hashable {
    case inherit
    case on
    case off

    init(_ value: Bool?) {
        switch value {
        case .some(true): self = .on
        case .some(false): self = .off
        case .none: self = .inherit
        }
    }

    var value: Bool? {
        switch self {
        case .inherit: nil
        case .on: true
        case .off: false
        }
    }
}

private enum DistanceMode: String, Hashable {
    case inherit
    case automatic
    case lines
    case pixels

    init(_ value: ScrollDistance?) {
        guard let value else {
            self = .inherit
            return
        }

        switch value {
        case .automatic: self = .automatic
        case .lines: self = .lines
        case .pixels: self = .pixels
        @unknown default: self = .inherit
        }
    }
}
