import AppKit
import JostleCore
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var loginItemController: LoginItemController
    let diagnosticsReportProvider: () -> String
    @State private var confirmsReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            Divider()

            Text("Menu Bar")
                .font(.headline)

            PreferenceRow(label: "Left-click:") {
                VStack(alignment: .leading, spacing: 5) {
                    Picker("", selection: leftClickTogglesKeepAwakeBinding) {
                        Text("Toggle Keep Awake").tag(true)
                        Text("Open Menu").tag(false)
                    }
                    .labelsHidden()
                    .frame(width: 180, alignment: .leading)
                    Text(clickBehaviorDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: "Device battery:") {
                VStack(alignment: .leading, spacing: 5) {
                    Picker("", selection: batteryDisplayModeBinding) {
                        ForEach(PointingDeviceBatteryDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180, alignment: .leading)
                    Text("Show the lowest available pointing-device battery level beside the icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: "Keep Awake icon:") {
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

            Spacer(minLength: 0)
            Divider()

            HStack {
                Button("Diagnostics…") {
                    DiagnosticsPreviewPresenter.present(
                        report: diagnosticsReportProvider()
                    )
                }
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
            Text("This also clears all app overrides.")
        }
    }

    private var clickBehaviorDescription: String {
        settingsStore.settings.keepAwakeActivateOnLeftClick
            ? "Right-click opens the menu."
            : "Right-click toggles Keep Awake."
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginItemController.isEnabled },
            set: { loginItemController.setEnabled($0) }
        )
    }

    private var leftClickTogglesKeepAwakeBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeActivateOnLeftClick },
            set: { value in settingsStore.update { $0.keepAwakeActivateOnLeftClick = value } }
        )
    }

    private var batteryDisplayModeBinding: Binding<PointingDeviceBatteryDisplayMode> {
        Binding(
            get: { settingsStore.settings.inputCustomization.batteryDisplayMode },
            set: { value in
                settingsStore.update { $0.inputCustomization.batteryDisplayMode = value }
            }
        )
    }

    private var indicatorStyleBinding: Binding<KeepAwakeIndicatorStyle> {
        Binding(
            get: { settingsStore.settings.keepAwakeIndicatorStyle },
            set: { value in settingsStore.update { $0.keepAwakeIndicatorStyle = value } }
        )
    }

    private var dimWhenInactiveBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.keepAwakeDimWhenInactive },
            set: { value in settingsStore.update { $0.keepAwakeDimWhenInactive = value } }
        )
    }
}

struct GesturesSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore

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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 660, height: 470)
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

struct InputSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var pointingDeviceManager: PointingDeviceManager
    @ObservedObject var conflictMonitor: InputUtilityConflictMonitor
    let safeMode: Bool
    @State private var confirmsInputReset = false
    @State private var configurationStatus: String?
    @State private var configurationStatusIsError = false

    private var displayedDevices: [PointingDeviceInfo] {
        var byID = Dictionary(
            uniqueKeysWithValues: pointingDeviceManager.devices.map { ($0.id, $0) }
        )
        for (key, rule) in settingsStore.settings.inputCustomization.deviceRules
        where byID[key] == nil {
            byID[key] = PointingDeviceInfo(
                id: key,
                displayName: "\(rule.displayName) — Disconnected",
                category: rule.category,
                registryID: nil
            )
        }
        return byID.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Input Customization")
                    .font(.headline)

                Toggle("Enable input customizations", isOn: enabledBinding)
                    .toggleStyle(.checkbox)
                    .disabled(safeMode)

                if safeMode {
                    Label(
                        "Jostle started in Safe Mode. Restart normally to enable input customizations.",
                        systemImage: "exclamationmark.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                if !conflictMonitor.conflicts.isEmpty {
                    Label(
                        "Also running: \(conflictMonitor.conflicts.joined(separator: ", ")). Overlapping input transformations may conflict.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("inputUtilityConflictWarning")
                }

                Text("Window gestures and Keep Awake remain independently available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Scrolling")
                    .font(.headline)

                PreferenceRow(label: "Direction:") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Reverse mouse scrolling", isOn: reverseMouseBinding)
                            .toggleStyle(.checkbox)
                        Toggle("Reverse trackpad scrolling", isOn: reverseTrackpadBinding)
                            .toggleStyle(.checkbox)
                    }
                }
                Divider()

                HStack {
                    Text("Scroll Profiles")
                        .font(.headline)
                    Spacer()
                    Button {
                        addScrollProfile()
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }
                }
                Text("Profiles can target a device, app, or process. Later matching profiles override earlier values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settingsStore.settings.inputCustomization.scrollProfiles.isEmpty {
                    Text("No custom scroll profiles.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(settingsStore.settings.inputCustomization.scrollProfiles.enumerated()), id: \.element.id) { index, profile in
                            ScrollProfileEditor(
                                profile: scrollProfileBinding(id: profile.id),
                                devices: displayedDevices,
                                canMoveUp: index > 0,
                                canMoveDown: index + 1 < settingsStore.settings.inputCustomization.scrollProfiles.count,
                                onMoveUp: { moveScrollProfile(at: index, offset: -1) },
                                onMoveDown: { moveScrollProfile(at: index, offset: 1) },
                                onDelete: { removeScrollProfile(id: profile.id) }
                            )
                        }
                    }
                }

                Divider()

                Text("Mouse Buttons")
                    .font(.headline)

                PreferenceRow(label: "Button 4:") {
                    actionPicker(selection: buttonFourBinding)
                }
                PreferenceRow(label: "Button 5:") {
                    actionPicker(selection: buttonFiveBinding)
                }
                Toggle("Universal Back and Forward", isOn: universalBackForwardBinding)
                    .toggleStyle(.checkbox)
                Text("Back and Forward apply only when Button 4 or 5 uses System Default. Move and Resize act while the selected button is dragged. Escape cancels the active window gesture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Focus Follows Pointer")
                    .font(.headline)

                PreferenceRow(label: "Devices:") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Allow for mice", isOn: focusMouseBinding)
                            .toggleStyle(.checkbox)
                        Toggle("Allow for trackpads", isOn: focusTrackpadBinding)
                            .toggleStyle(.checkbox)
                        Text("The Apps pane still controls which applications use pointer focus.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text("Device Overrides")
                    .font(.headline)

                if displayedDevices.isEmpty {
                    Text("No pointing devices detected.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(displayedDevices) { device in
                            HStack(spacing: 10) {
                                Image(systemName: device.category == .trackpad
                                    ? "rectangle.and.hand.point.up.left"
                                    : "computermouse")
                                    .frame(width: 22)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                        .lineLimit(1)
                                    Text(device.category.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                featurePicker(
                                    title: "Scroll",
                                    selection: deviceReverseBinding(device),
                                    defaultEnabled: categoryReverseDefault(device.category)
                                )
                                featurePicker(
                                    title: "Focus",
                                    selection: deviceFocusBinding(device),
                                    defaultEnabled: categoryFocusDefault(device.category)
                                )
                                if settingsStore.settings.inputCustomization.deviceRules[device.id] != nil {
                                    Button {
                                        settingsStore.update {
                                            $0.inputCustomization.removeDeviceRule(key: device.id)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Forget this device override")
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            if device.id != displayedDevices.last?.id {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
                }

                Divider()

                Text("Configuration")
                    .font(.headline)
                HStack {
                    Button("Export Input Settings…") {
                        exportInputConfiguration()
                    }
                    Button("Import Input Settings…") {
                        importInputConfiguration()
                    }
                    Spacer()
                    Button("Reset Input Settings…", role: .destructive) {
                        confirmsInputReset = true
                    }
                }
                Text("These operations affect only scrolling, mouse buttons, device overrides, and input battery presentation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let configurationStatus {
                    Text(configurationStatus)
                        .font(.caption)
                        .foregroundStyle(configurationStatusIsError ? .red : .secondary)
                        .accessibilityIdentifier("inputConfigurationStatus")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 660, height: 470)
        .alert("Reset input customizations?", isPresented: $confirmsInputReset) {
            Button("Reset", role: .destructive) {
                settingsStore.resetInputCustomization()
                configurationStatusIsError = false
                configurationStatus = "Input customization settings were reset."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Window, Keep Awake, login, update, and application settings will not change.")
        }
    }

    private func exportInputConfiguration() {
        let data: Data
        do {
            data = try settingsStore.exportInputCustomization()
        } catch {
            configurationStatusIsError = true
            configurationStatus = "Could not prepare the backup: \(error.localizedDescription)"
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Input Settings"
        panel.message = "The backup contains only Jostle input customization settings."
        panel.nameFieldStringValue = "jostle-input-settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        present(panel: panel) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                configurationStatusIsError = false
                configurationStatus = "Input settings were exported."
            } catch {
                configurationStatusIsError = true
                configurationStatus = "Could not export input settings: \(error.localizedDescription)"
            }
        }
    }

    private func importInputConfiguration() {
        let panel = NSOpenPanel()
        panel.title = "Import Input Settings"
        panel.message = "This replaces only Jostle input customization settings."
        panel.prompt = "Import"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        present(panel: panel) { response in
            guard response == .OK, let url = panel.url else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                try settingsStore.importInputCustomization(from: Data(contentsOf: url))
                configurationStatusIsError = false
                configurationStatus = "Input settings were imported."
            } catch {
                configurationStatusIsError = true
                configurationStatus = "Could not import input settings: \(error.localizedDescription)"
            }
        }
    }

    private func present(
        panel: NSSavePanel,
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    private func actionPicker(selection: Binding<PointerButtonAction>) -> some View {
        Picker("", selection: selection) {
            ForEach(PointerButtonAction.allCases, id: \.self) { action in
                Text(action.title).tag(action)
            }
        }
        .labelsHidden()
        .frame(width: 190, alignment: .leading)
    }

    private func featurePicker(
        title: String,
        selection: Binding<ApplicationFeatureSetting>,
        defaultEnabled: Bool
    ) -> some View {
        Picker(title, selection: selection) {
            Text("Default (\(defaultEnabled ? "On" : "Off"))")
                .tag(ApplicationFeatureSetting.useDefault)
            Text("On").tag(ApplicationFeatureSetting.enabled)
            Text("Off").tag(ApplicationFeatureSetting.disabled)
        }
        .frame(width: 116)
    }

    private func categoryReverseDefault(_ category: PointingDeviceCategory) -> Bool {
        switch category {
        case .mouse: settingsStore.settings.inputCustomization.reverseMouseScrolling
        case .trackpad: settingsStore.settings.inputCustomization.reverseTrackpadScrolling
        case .unknown: false
        }
    }

    private func categoryFocusDefault(_ category: PointingDeviceCategory) -> Bool {
        switch category {
        case .mouse: settingsStore.settings.inputCustomization.focusFollowsPointerForMouse
        case .trackpad: settingsStore.settings.inputCustomization.focusFollowsPointerForTrackpad
        case .unknown: true
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.inputCustomization.isEnabled },
            set: { value in settingsStore.update { $0.inputCustomization.isEnabled = value } }
        )
    }

    private var reverseMouseBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.inputCustomization.reverseMouseScrolling },
            set: { value in
                settingsStore.update { $0.inputCustomization.reverseMouseScrolling = value }
            }
        )
    }

    private var reverseTrackpadBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.inputCustomization.reverseTrackpadScrolling },
            set: { value in
                settingsStore.update { $0.inputCustomization.reverseTrackpadScrolling = value }
            }
        )
    }

    private func scrollProfileBinding(id: String) -> Binding<ScrollProfile> {
        Binding(
            get: {
                settingsStore.settings.inputCustomization.scrollProfiles.first { $0.id == id }
                    ?? ScrollProfile(name: "Missing Profile")
            },
            set: { value in
                settingsStore.update { settings in
                    guard let index = settings.inputCustomization.scrollProfiles.firstIndex(
                        where: { $0.id == id }
                    ) else { return }
                    settings.inputCustomization.scrollProfiles[index] = value
                }
            }
        )
    }

    private func addScrollProfile() {
        settingsStore.update {
            $0.inputCustomization.scrollProfiles.append(ScrollProfile(
                name: "New Mouse Profile",
                match: ScrollProfileMatch(deviceCategory: .mouse)
            ))
        }
    }

    private func moveScrollProfile(at index: Int, offset: Int) {
        settingsStore.update { settings in
            let destination = index + offset
            guard settings.inputCustomization.scrollProfiles.indices.contains(index),
                  settings.inputCustomization.scrollProfiles.indices.contains(destination) else {
                return
            }
            settings.inputCustomization.scrollProfiles.swapAt(index, destination)
        }
    }

    private func removeScrollProfile(id: String) {
        settingsStore.update {
            $0.inputCustomization.scrollProfiles.removeAll { $0.id == id }
        }
    }

    private var universalBackForwardBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.inputCustomization.universalBackForward },
            set: { value in
                settingsStore.update { $0.inputCustomization.universalBackForward = value }
            }
        )
    }

    private var buttonFourBinding: Binding<PointerButtonAction> {
        Binding(
            get: { settingsStore.settings.inputCustomization.buttonFourAction },
            set: { value in settingsStore.update { $0.inputCustomization.buttonFourAction = value } }
        )
    }

    private var buttonFiveBinding: Binding<PointerButtonAction> {
        Binding(
            get: { settingsStore.settings.inputCustomization.buttonFiveAction },
            set: { value in settingsStore.update { $0.inputCustomization.buttonFiveAction = value } }
        )
    }

    private var focusMouseBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.inputCustomization.focusFollowsPointerForMouse },
            set: { value in
                settingsStore.update { $0.inputCustomization.focusFollowsPointerForMouse = value }
            }
        )
    }

    private var focusTrackpadBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.inputCustomization.focusFollowsPointerForTrackpad },
            set: { value in
                settingsStore.update { $0.inputCustomization.focusFollowsPointerForTrackpad = value }
            }
        )
    }

    private func deviceReverseBinding(_ device: PointingDeviceInfo) -> Binding<ApplicationFeatureSetting> {
        Binding(
            get: {
                settingsStore.settings.inputCustomization.deviceRules[device.id]?.reverseScrolling
                    ?? .useDefault
            },
            set: { value in
                settingsStore.update {
                    $0.inputCustomization.setDeviceRule(
                        key: device.id,
                        displayName: device.displayName.replacingOccurrences(
                            of: " — Disconnected",
                            with: ""
                        ),
                        category: device.category,
                        reverseScrolling: value
                    )
                }
            }
        )
    }

    private func deviceFocusBinding(_ device: PointingDeviceInfo) -> Binding<ApplicationFeatureSetting> {
        Binding(
            get: {
                settingsStore.settings.inputCustomization.deviceRules[device.id]?.focusFollowsPointer
                    ?? .useDefault
            },
            set: { value in
                settingsStore.update {
                    $0.inputCustomization.setDeviceRule(
                        key: device.id,
                        displayName: device.displayName.replacingOccurrences(
                            of: " — Disconnected",
                            with: ""
                        ),
                        category: device.category,
                        focusFollowsPointer: value
                    )
                }
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
                    Toggle("Activate Keep Awake when Jostle launches", isOn: activateAtLaunchBinding)
                        .toggleStyle(.checkbox)
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

            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 660, height: 470)
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

struct ApplicationsSettingsPane: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var runningApplications: [RunningApplicationInfo] = []

    private let focusDelays: [(value: Double, title: String)] = [
        (0, "Immediate"),
        (0.1, "100 ms"),
        (0.25, "250 ms"),
        (0.5, "500 ms")
    ]

    private var applications: [(key: String, rule: ApplicationRule)] {
        settingsStore.settings.applicationRules
            .map { (key: $0.key, rule: $0.value) }
            .sorted {
                let order = $0.rule.displayName.localizedCaseInsensitiveCompare(
                    $1.rule.displayName
                )
                return order == .orderedSame ? $0.key < $1.key : order == .orderedAscending
            }
    }

    private var availableRunningApplications: [RunningApplicationInfo] {
        runningApplications.filter {
            settingsStore.settings.applicationRules[$0.key] == nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Defaults")
                .font(.headline)

            PreferenceRow(label: "Window controls:") {
                Toggle(
                    "Enable move, resize, and snapping",
                    isOn: windowControlsDefaultBinding
                )
                .toggleStyle(.checkbox)
            }

            PreferenceRow(label: "Pointer focus:") {
                Toggle(
                    "Focus follows pointer",
                    isOn: focusDefaultBinding
                )
                .toggleStyle(.checkbox)
            }

            PreferenceRow(label: "Focus delay:") {
                Picker("", selection: focusDelayBinding) {
                    ForEach(focusDelays, id: \.value) { delay in
                        Text(delay.title).tag(delay.value)
                    }
                }
                .labelsHidden()
                .frame(width: 130, alignment: .leading)
                .disabled(!settingsStore.settings.hasEnabledFocusFollowsPointerRule)
            }

            Text(
                "Defaults apply unless an app has an override below. "
                    + "Pointer focus raises the window after the pointer rests for the selected delay."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text("App Overrides")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(availableRunningApplications, id: \.key) { application in
                        Button(application.name) {
                            settingsStore.update { settings in
                                settings.addApplicationRule(
                                    key: application.key,
                                    displayName: application.name
                                )
                            }
                        }
                    }
                } label: {
                    Label("Add Running App", systemImage: "plus")
                }
                .disabled(availableRunningApplications.isEmpty)
            }

            if applications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No app overrides")
                        .font(.headline)
                    Text("Add a running app here, or use the current-app controls in the menu bar.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text("Application")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Window controls")
                            .frame(width: 130, alignment: .leading)
                        Text("Pointer focus")
                            .frame(width: 120, alignment: .leading)
                        Color.clear.frame(width: 22, height: 1)
                        Color.clear.frame(width: 22, height: 1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(applications, id: \.key) { application in
                                HStack(spacing: 10) {
                                    applicationLabel(
                                        key: application.key,
                                        name: application.rule.displayName
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    featurePicker(
                                        selection: windowControlsBinding(for: application.key),
                                        defaultEnabled: settingsStore.settings.windowControlsEnabledByDefault
                                    )
                                    .frame(width: 130)

                                    featurePicker(
                                        selection: focusBinding(for: application.key),
                                        defaultEnabled: settingsStore.settings.focusFollowsPointerEnabledByDefault
                                    )
                                    .frame(width: 120)

                                    Menu {
                                        Section("Input Compatibility") {
                                            Toggle(
                                                "Clear Stuck Command after Switching",
                                                isOn: commandKeyRecoveryBinding(for: application.key)
                                            )
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                    }
                                    .menuStyle(.borderlessButton)
                                    .frame(width: 22)
                                    .help(
                                        "Input compatibility options for "
                                            + application.rule.displayName
                                    )
                                    .accessibilityLabel(
                                        "Input compatibility options for \(application.rule.displayName)"
                                    )

                                    Button {
                                        settingsStore.update {
                                            $0.removeApplicationRule(key: application.key)
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remove override for \(application.rule.displayName)")
                                    .accessibilityLabel(
                                        "Remove \(application.rule.displayName) override"
                                    )
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)

                                if application.key != applications.last?.key {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 660, height: 470)
        .onAppear(perform: refreshRunningApplications)
    }

    @ViewBuilder
    private func applicationLabel(key: String, name: String) -> some View {
        HStack(spacing: 10) {
            if let icon = ApplicationIconProvider.icon(
                applicationKey: key,
                displayName: name
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
                Text(name)
                    .lineLimit(1)
                if key != name {
                    Text(key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func featurePicker(
        selection: Binding<ApplicationFeatureSetting>,
        defaultEnabled: Bool
    ) -> some View {
        Picker("", selection: selection) {
            Text("Default (\(defaultEnabled ? "On" : "Off"))")
                .tag(ApplicationFeatureSetting.useDefault)
            Text("On").tag(ApplicationFeatureSetting.enabled)
            Text("Off").tag(ApplicationFeatureSetting.disabled)
        }
        .labelsHidden()
    }

    private var windowControlsDefaultBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.windowControlsEnabledByDefault },
            set: { value in
                settingsStore.update { $0.windowControlsEnabledByDefault = value }
            }
        )
    }

    private var focusDefaultBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.focusFollowsPointerEnabledByDefault },
            set: { value in
                settingsStore.update { $0.focusFollowsPointerEnabledByDefault = value }
            }
        )
    }

    private var focusDelayBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.focusFollowsPointerDelay },
            set: { value in
                settingsStore.update { $0.focusFollowsPointerDelay = value }
            }
        )
    }

    private func windowControlsBinding(for key: String) -> Binding<ApplicationFeatureSetting> {
        Binding(
            get: {
                settingsStore.settings.applicationRules[key]?.windowControls ?? .useDefault
            },
            set: { value in
                guard let rule = settingsStore.settings.applicationRules[key] else { return }
                settingsStore.update {
                    $0.setWindowControls(
                        value,
                        forApplicationKey: key,
                        displayName: rule.displayName
                    )
                }
            }
        )
    }

    private func focusBinding(for key: String) -> Binding<ApplicationFeatureSetting> {
        Binding(
            get: {
                settingsStore.settings.applicationRules[key]?.focusFollowsPointer ?? .useDefault
            },
            set: { value in
                guard let rule = settingsStore.settings.applicationRules[key] else { return }
                settingsStore.update {
                    $0.setFocusFollowsPointer(
                        value,
                        forApplicationKey: key,
                        displayName: rule.displayName
                    )
                }
            }
        )
    }

    private func commandKeyRecoveryBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: {
                settingsStore.settings.commandKeyRecoveryEnabled(forApplicationKey: key)
            },
            set: { enabled in
                guard let rule = settingsStore.settings.applicationRules[key] else { return }
                settingsStore.update {
                    $0.setCommandKeyRecovery(
                        enabled,
                        forApplicationKey: key,
                        displayName: rule.displayName
                    )
                }
            }
        )
    }

    private func refreshRunningApplications() {
        var applicationsByKey: [String: RunningApplicationInfo] = [:]
        for application in NSWorkspace.shared.runningApplications
        where application.processIdentifier != ProcessInfo.processInfo.processIdentifier
            && application.activationPolicy == .regular {
            guard let info = RunningApplicationInfo(application: application) else { continue }
            applicationsByKey[info.key] = info
        }
        runningApplications = applicationsByKey.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
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
