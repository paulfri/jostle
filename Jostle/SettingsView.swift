import JostleCore
import SwiftUI

struct GeneralSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var loginItemController: LoginItemController
    @State private var confirmsReset = false

    private let modifierOptions: [(modifier: JostleCore.Modifier, title: String)] = [
        (.control, "⌃ Control"),
        (.option, "⌥ Option"),
        (.shift, "⇧ Shift"),
        (.command, "⌘ Command"),
        (.function, "fn Function")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activation")
                .font(.headline)

            PreferenceRow(label: "Modifier keys:") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(modifierOptions, id: \.modifier) { option in
                        Toggle(option.title, isOn: modifierBinding(option.modifier))
                            .toggleStyle(.checkbox)
                            .fixedSize()
                    }
                }
            }

            PreferenceRow(label: "") {
                Text("Hold this exact combination while dragging a window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Window Behavior")
                .font(.headline)

            PreferenceRow(label: "Resize with:") {
                Picker("", selection: middleClickResizeBinding) {
                    Text("Right Click").tag(false)
                    Text("Middle Click").tag(true)
                }
                .labelsHidden()
                .frame(width: 170, alignment: .leading)
            }

            PreferenceRow(label: "") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Bring windows to the front", isOn: bringToFrontBinding)
                        .toggleStyle(.checkbox)
                    Toggle("Resize only", isOn: resizeOnlyBinding)
                        .toggleStyle(.checkbox)
                    Text("Resize Only lets modifier-left-drag pass through to the current app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Show active resize edge", isOn: resizeFeedbackBinding)
                        .toggleStyle(.checkbox)
                }
            }

            Divider()

            Text("Startup")
                .font(.headline)

            PreferenceRow(label: "") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Start \(AppBrand.applicationName) at login", isOn: startAtLoginBinding)
                        .toggleStyle(.checkbox)
                    if let errorMessage = loginItemController.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer(minLength: 0)
            Divider()

            HStack {
                Spacer()
                Button("Restore Defaults…") {
                    confirmsReset = true
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 660, height: 470)
        .alert("Restore \(AppBrand.applicationName) defaults?", isPresented: $confirmsReset) {
            Button("Restore", role: .destructive) {
                settingsStore.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also clears the excluded applications list.")
        }
    }

    private func modifierBinding(_ modifier: JostleCore.Modifier) -> Binding<Bool> {
        Binding(
            get: { settingsStore.settings.modifiers.contains(modifier) },
            set: { enabled in
                guard enabled || settingsStore.settings.modifiers.count > 1 else { return }
                settingsStore.update { settings in
                    settings.setModifier(modifier, enabled: enabled)
                }
            }
        )
    }

    private var middleClickResizeBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.middleClickResize },
            set: { value in
                settingsStore.update { $0.middleClickResize = value }
            }
        )
    }

    private var bringToFrontBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.bringWindowToFront },
            set: { value in
                settingsStore.update { $0.bringWindowToFront = value }
            }
        )
    }

    private var resizeOnlyBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.resizeOnly },
            set: { value in
                settingsStore.update { $0.resizeOnly = value }
            }
        )
    }

    private var resizeFeedbackBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.resizeFeedbackEnabled },
            set: { value in
                settingsStore.update { $0.resizeFeedbackEnabled = value }
            }
        )
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginItemController.isEnabled },
            set: { loginItemController.setEnabled($0) }
        )
    }
}

struct SnappingSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edge Snapping")
                .font(.headline)

            PreferenceRow(label: "") {
                Toggle("Snap windows when dragged to a screen edge", isOn: snapEnabledBinding)
                    .toggleStyle(.checkbox)
            }

            PreferenceRow(label: "") {
                Text("Drag to the left or right edge for a half, a corner for a quarter, or the top edge to fill the usable screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 430, alignment: .leading)
            }

            PreferenceRow(label: "") {
                Toggle("Enable modifier-double-click actions", isOn: doubleClickActionsBinding)
                    .toggleStyle(.checkbox)
            }

            PreferenceRow(label: "") {
                Text("Double-left-click maximizes or restores. Double-clicking with the resize button tiles toward the clicked region.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 430, alignment: .leading)
            }

            Divider()

            Text("Spacing")
                .font(.headline)

            PreferenceRow(label: "Tile gap:") {
                Stepper(value: snapGapBinding, in: 0...32, step: 1) {
                    Text("\(Int(settingsStore.settings.snapGap)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .leading)
                }
                .disabled(!settingsStore.settings.snapEnabled)
            }

            PreferenceRow(label: "Screen margin:") {
                Stepper(value: snapScreenMarginBinding, in: 0...64, step: 1) {
                    Text("\(Int(settingsStore.settings.snapScreenMargin)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .leading)
                }
                .disabled(!settingsStore.settings.snapEnabled)
            }

            PreferenceRow(label: "") {
                Text("The tile gap separates adjacent windows. The screen margin reserves space around the usable display area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 430, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 660, height: 470)
    }

    private var doubleClickActionsBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.doubleClickActionsEnabled },
            set: { value in
                settingsStore.update { $0.doubleClickActionsEnabled = value }
            }
        )
    }

    private var snapEnabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.snapEnabled },
            set: { value in
                settingsStore.update { $0.snapEnabled = value }
            }
        )
    }

    private var snapGapBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.snapGap },
            set: { value in
                settingsStore.update { $0.snapGap = value }
            }
        )
    }

    private var snapScreenMarginBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.snapScreenMargin },
            set: { value in
                settingsStore.update { $0.snapScreenMargin = value }
            }
        )
    }
}

struct KeepAwakeSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var globalShortcutController: GlobalShortcutController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Session")
                    .font(.headline)

                PreferenceRow(label: "Default duration:") {
                    Picker("", selection: defaultDurationBinding) {
                        ForEach(KeepAwakeDurationPreset.allCases, id: \.self) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180, alignment: .leading)
                }

                PreferenceRow(label: "") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Activate Keep Awake when Jostle launches", isOn: activateAtLaunchBinding)
                            .toggleStyle(.checkbox)
                        Toggle("Activate Keep Awake on left-click", isOn: activateOnLeftClickBinding)
                            .toggleStyle(.checkbox)
                        Text(clickBehaviorDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text("Keyboard Shortcut")
                    .font(.headline)

                PreferenceRow(label: "Toggle:") {
                    VStack(alignment: .leading, spacing: 5) {
                        ShortcutRecorder(shortcut: shortcutBinding)
                            .frame(width: 180, height: 26)
                        Text("Recommended: ⌃⌘L. Press Delete while recording to clear it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let errorMessage = globalShortcutController.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Divider()

                Text("Sleep Behavior")
                    .font(.headline)

                PreferenceRow(label: "") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(
                            "Allow display to sleep while keeping computer awake",
                            isOn: allowDisplaySleepBinding
                        )
                        .toggleStyle(.checkbox)
                        Toggle("Allow sleep while screen is locked", isOn: allowSleepWhenLockedBinding)
                            .toggleStyle(.checkbox)
                        Toggle("Deactivate when switching to battery", isOn: deactivateOnBatteryBinding)
                            .toggleStyle(.checkbox)
                        Text("Battery deactivation does not reactivate when external power returns.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text("Menu Bar")
                    .font(.headline)

                PreferenceRow(label: "Active indicator:") {
                    Picker("", selection: indicatorStyleBinding) {
                        ForEach(KeepAwakeIndicatorStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180, alignment: .leading)
                }

                PreferenceRow(label: "") {
                    Toggle("Dim icon while Keep Awake is inactive", isOn: dimWhenInactiveBinding)
                        .toggleStyle(.checkbox)
                }

                Divider()

                Text("Advanced")
                    .font(.headline)

                PreferenceRow(label: "") {
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle("Use improved monotonic timer", isOn: improvedTimerBinding)
                            .toggleStyle(.checkbox)
                        Text("Monotonic timing is resilient to changes to the system clock.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 660, height: 470)
    }

    private var clickBehaviorDescription: String {
        settingsStore.settings.keepAwakeActivateOnLeftClick
            ? "Left-click toggles Keep Awake; right-click opens the menu."
            : "Right-click toggles Keep Awake; left-click opens the menu."
    }

    private var defaultDurationBinding: Binding<KeepAwakeDurationPreset> {
        Binding(
            get: { settingsStore.settings.keepAwakeDefaultDuration },
            set: { value in settingsStore.update { $0.keepAwakeDefaultDuration = value } }
        )
    }

    private var activateAtLaunchBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeActivateAtLaunch },
            set: { value in settingsStore.update { $0.keepAwakeActivateAtLaunch = value } }
        )
    }

    private var activateOnLeftClickBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeActivateOnLeftClick },
            set: { value in settingsStore.update { $0.keepAwakeActivateOnLeftClick = value } }
        )
    }

    private var shortcutBinding: Binding<GlobalShortcut?> {
        Binding(
            get: { settingsStore.settings.keepAwakeShortcut },
            set: { value in settingsStore.update { $0.keepAwakeShortcut = value } }
        )
    }

    private var allowDisplaySleepBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeAllowDisplaySleep },
            set: { value in settingsStore.update { $0.keepAwakeAllowDisplaySleep = value } }
        )
    }

    private var allowSleepWhenLockedBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeAllowSleepWhenLocked },
            set: { value in settingsStore.update { $0.keepAwakeAllowSleepWhenLocked = value } }
        )
    }

    private var deactivateOnBatteryBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeDeactivateOnBattery },
            set: { value in settingsStore.update { $0.keepAwakeDeactivateOnBattery = value } }
        )
    }

    private var dimWhenInactiveBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeDimWhenInactive },
            set: { value in settingsStore.update { $0.keepAwakeDimWhenInactive = value } }
        )
    }

    private var indicatorStyleBinding: Binding<KeepAwakeIndicatorStyle> {
        Binding(
            get: { settingsStore.settings.keepAwakeIndicatorStyle },
            set: { value in settingsStore.update { $0.keepAwakeIndicatorStyle = value } }
        )
    }

    private var improvedTimerBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeUseImprovedTimer },
            set: { value in settingsStore.update { $0.keepAwakeUseImprovedTimer = value } }
        )
    }
}

struct UpdateSettingsPane: View {
    @ObservedObject private var updateController: SparkleUpdateController
    @State private var automaticallyChecksForUpdates: Bool

    init(updateController: SparkleUpdateController) {
        self.updateController = updateController
        _automaticallyChecksForUpdates = State(
            initialValue: updateController.automaticallyChecksForUpdates
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Automatic Updates")
                .font(.headline)

            Toggle(
                "Automatically check for updates",
                isOn: automaticallyChecksBinding
            )
            .toggleStyle(.checkbox)

            Text("When enabled, Jostle checks for a new release once per day.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("Manual Updates")
                .font(.headline)

            Button("Check for Updates…") {
                updateController.checkForUpdates()
            }
            .disabled(!updateController.canCheckForUpdates)

            Text("Installed version: \(Self.installedVersion)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 660, height: 470)
    }

    private var automaticallyChecksBinding: Binding<Bool> {
        Binding(
            get: { automaticallyChecksForUpdates },
            set: { enabled in
                automaticallyChecksForUpdates = enabled
                updateController.setAutomaticallyChecksForUpdates(enabled)
            }
        )
    }

    private static var installedVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }
}

struct ExcludedApplicationsSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore

    private var applications: [(key: String, name: String)] {
        settingsStore.settings.excludedApplications
            .map { (key: $0.key, name: $0.value) }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.key < $1.key : order == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Excluded Applications")
                .font(.headline)
            Text("\(AppBrand.applicationName) ignores windows belonging to these applications.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if applications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No excluded applications")
                        .font(.headline)
                    Text("After dragging a window, choose Exclude from the \(AppBrand.applicationName) menu.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(applications, id: \.key) { application in
                    HStack(spacing: 10) {
                        if let icon = ApplicationIconProvider.icon(
                            applicationKey: application.key,
                            displayName: application.name
                        ) {
                            Image(nsImage: icon)
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.name)
                            if application.key != application.name {
                                Text(application.key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer()
                        Button {
                            settingsStore.update { settings in
                                settings.setApplicationExcluded(
                                    key: application.key,
                                    displayName: nil,
                                    excluded: false
                                )
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove \(application.name) from exclusions")
                        .accessibilityLabel("Remove \(application.name)")
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 660, height: 470)
    }
}

private struct PreferenceRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .frame(width: 108, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }
}
