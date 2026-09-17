import JostleCore
import SwiftUI

struct GeneralSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore
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
                            .disabled(isOnlySelectedModifier(option.modifier))
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
                .frame(width: 170)
                .offset(x: -24)
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
        .frame(width: 660, height: 390)
        .alert("Restore Jostle defaults?", isPresented: $confirmsReset) {
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

    private func isOnlySelectedModifier(_ modifier: JostleCore.Modifier) -> Bool {
        settingsStore.settings.modifiers == [modifier]
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
            Text("Jostle ignores windows belonging to these applications.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if applications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No excluded applications")
                        .font(.headline)
                    Text("After dragging a window, choose Exclude from the Jostle menu.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(applications, id: \.key) { application in
                    HStack(spacing: 10) {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
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
        .frame(width: 660, height: 390)
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
