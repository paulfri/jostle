import SwiftUI
import JostleCore

struct JostleSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ExcludedApplicationsSettingsView(settingsStore: settingsStore)
                .tabItem {
                    Label("Excluded Apps", systemImage: "nosign")
                }
        }
        .frame(width: 520, height: 360)
    }
}

private struct GeneralSettingsView: View {
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
        Form {
            Section("Activation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modifier keys")
                    HStack(spacing: 16) {
                        ForEach(modifierOptions, id: \.modifier) { option in
                            Toggle(option.title, isOn: modifierBinding(option.modifier))
                                .toggleStyle(.checkbox)
                                .disabled(isOnlySelectedModifier(option.modifier))
                        }
                    }
                    Text("Hold this exact combination while dragging a window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Window Behavior") {
                Picker("Resize with", selection: middleClickResizeBinding) {
                    Text("Right Click").tag(false)
                    Text("Middle Click").tag(true)
                }

                Toggle("Bring the window to the front when a drag begins", isOn: bringToFrontBinding)
                Toggle("Resize only; let modifier-left-drag pass through", isOn: resizeOnlyBinding)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset All Settings…") {
                        confirmsReset = true
                    }
                }
            }
        }
        .padding(20)
        .alert("Reset all Jostle settings?", isPresented: $confirmsReset) {
            Button("Reset", role: .destructive) {
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

private struct ExcludedApplicationsSettingsView: View {
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
        VStack(alignment: .leading, spacing: 16) {
            if applications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No Excluded Applications")
                        .font(.headline)
                    Text("After dragging a window, use “Exclude” in the Jostle menu to add its app here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Jostle ignores windows belonging to these applications.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                List(applications, id: \.key) { application in
                    HStack(spacing: 12) {
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
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }
}
