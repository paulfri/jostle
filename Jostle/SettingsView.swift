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
