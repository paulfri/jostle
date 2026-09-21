import AppKit
import Combine
import Foundation
import JostleCore
import UniformTypeIdentifiers

struct RunningApplicationIdentity: Equatable {
    var bundleIdentifier: String?
    var localizedName: String?
}

enum InputUtilityConflictDetector {
    private struct KnownUtility {
        let displayName: String
        let bundleIdentifierFragments: [String]
        let normalizedNameFragments: [String]
    }

    private static let knownUtilities: [KnownUtility] = [
        KnownUtility(
            displayName: "LinearMouse",
            bundleIdentifierFragments: ["linearmouse"],
            normalizedNameFragments: ["linearmouse"]
        ),
        KnownUtility(
            displayName: "SteerMouse",
            bundleIdentifierFragments: ["steermouse"],
            normalizedNameFragments: ["steermouse"]
        ),
        KnownUtility(
            displayName: "BetterMouse",
            bundleIdentifierFragments: ["bettermouse"],
            normalizedNameFragments: ["bettermouse"]
        ),
        KnownUtility(
            displayName: "Mac Mouse Fix",
            bundleIdentifierFragments: ["macmousefix"],
            normalizedNameFragments: ["macmousefix"]
        ),
        KnownUtility(
            displayName: "USB Overdrive",
            bundleIdentifierFragments: ["usboverdrive"],
            normalizedNameFragments: ["usboverdrive"]
        ),
        KnownUtility(
            displayName: "Scroll Reverser",
            bundleIdentifierFragments: ["scrollreverser"],
            normalizedNameFragments: ["scrollreverser"]
        ),
        KnownUtility(
            displayName: "Mos",
            bundleIdentifierFragments: ["caldis.mos"],
            normalizedNameFragments: ["mos"]
        ),
        KnownUtility(
            displayName: "Logi Options+",
            bundleIdentifierFragments: ["logioptions", "logi.options"],
            normalizedNameFragments: ["logioptions"]
        ),
        KnownUtility(
            displayName: "Karabiner-Elements",
            bundleIdentifierFragments: ["karabiner"],
            normalizedNameFragments: ["karabinerelements"]
        ),
    ]

    static func conflicts(
        applications: [RunningApplicationIdentity],
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> [String] {
        let currentBundleIdentifier = currentBundleIdentifier?.lowercased()
        return knownUtilities.compactMap { utility in
            let isRunning = applications.contains { application in
                let bundleIdentifier = application.bundleIdentifier?.lowercased()
                if bundleIdentifier == currentBundleIdentifier { return false }
                if let bundleIdentifier,
                   utility.bundleIdentifierFragments.contains(where: bundleIdentifier.contains) {
                    return true
                }
                let name = normalized(application.localizedName)
                return utility.normalizedNameFragments.contains { fragment in
                    fragment.count <= 3 ? name == fragment : name.contains(fragment)
                }
            }
            return isRunning ? utility.displayName : nil
        }
    }

    static func currentConflicts(workspace: NSWorkspace = .shared) -> [String] {
        conflicts(applications: workspace.runningApplications.map {
            RunningApplicationIdentity(
                bundleIdentifier: $0.bundleIdentifier,
                localizedName: $0.localizedName
            )
        })
    }

    private static func normalized(_ value: String?) -> String {
        value?.lowercased().filter(\.isLetter) ?? ""
    }
}

@MainActor
final class InputUtilityConflictMonitor: ObservableObject {
    @Published private(set) var conflicts: [String] = []

    private let workspace: NSWorkspace
    private var observers: [NSObjectProtocol] = []

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        refresh()
        let center = workspace.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ] {
            observers.append(center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
    }

    deinit {
        let center = workspace.notificationCenter
        observers.forEach(center.removeObserver)
    }

    func refresh() {
        conflicts = InputUtilityConflictDetector.currentConflicts(workspace: workspace)
    }
}

struct InputDiagnosticsReportContext {
    var eventTapRequested: Bool
    var eventTapOperational: Bool
    var inputCustomizationsEnabled: Bool
    var safeMode: Bool
    var sessionActive: Bool
    var accessibilityTrusted: Bool
    var connectedDeviceCounts: [PointingDeviceCategory: Int]
    var conflictingUtilities: [String]
}

@MainActor
enum DiagnosticsPreviewPresenter {
    static func present(report: String) {
        present(report: report, parentWindow: NSApp.keyWindow)
    }

    static func present(report: String, parentWindow: NSWindow?) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 560, height: 300))
        textView.string = report
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        let scrollView = NSScrollView(frame: textView.frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        let alert = NSAlert()
        alert.messageText = "Jostle Diagnostics"
        alert.informativeText = "Review this privacy-redacted report before saving or copying it."
        alert.accessoryView = scrollView
        alert.addButton(withTitle: "Export…")
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Close")

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            switch response {
            case .alertFirstButtonReturn:
                export(report: report, parentWindow: parentWindow)
            case .alertSecondButtonReturn:
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(report, forType: .string)
            default:
                break
            }
        }

        if let parentWindow {
            alert.beginSheetModal(for: parentWindow, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private static func export(report: String, parentWindow: NSWindow?) {
        let panel = NSSavePanel()
        panel.title = "Export Jostle Diagnostics"
        panel.nameFieldStringValue = "jostle-diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try report.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                if let parentWindow {
                    alert.beginSheetModal(for: parentWindow)
                } else {
                    alert.runModal()
                }
            }
        }

        if let parentWindow {
            panel.beginSheetModal(for: parentWindow, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }
}

enum InputDiagnosticsReport {
    static func make(
        settings: JostleSettings,
        runtime: InputRuntimeDiagnosticsSnapshot,
        context: InputDiagnosticsReportContext,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        generatedAt: Date = Date()
    ) -> String {
        let input = settings.inputCustomization
        let enabledProfiles = input.scrollProfiles.filter(\.isEnabled).count
        let customButtonCount = [input.buttonFourAction, input.buttonFiveAction]
            .filter { $0 != .systemDefault }
            .count
        let exactMouseRules = input.deviceRules.values.filter { $0.category == .mouse }.count
        let exactTrackpadRules = input.deviceRules.values.filter { $0.category == .trackpad }.count
        let exactUnknownRules = input.deviceRules.values.filter { $0.category == .unknown }.count
        let conflicts = context.conflictingUtilities.isEmpty
            ? "none detected"
            : context.conflictingUtilities.sorted().joined(separator: ", ")
        let os = processInfo.operatingSystemVersion

        return """
        Jostle Diagnostics
        Generated: \(ISO8601DateFormatter().string(from: generatedAt))
        Privacy: aggregate settings and runtime counters only; no keys, pointer coordinates, application names, device names, device identifiers, serial numbers, or file-system paths are included.

        Application
        name: \(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Jostle")
        version: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
        build: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")
        macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)
        architecture: \(architecture)
        accessibility_trusted: \(yesNo(context.accessibilityTrusted))
        safe_mode: \(yesNo(context.safeMode))
        session_active: \(yesNo(context.sessionActive))

        Event Tap
        requested: \(yesNo(context.eventTapRequested))
        operational: \(yesNo(context.eventTapOperational))
        input_customizations_active: \(yesNo(context.inputCustomizationsEnabled))
        callback_samples: \(runtime.eventTap.sampleCount)
        callback_average_us: \(format(runtime.eventTap.averageMicroseconds))
        callback_p95_approx_us: \(format(runtime.eventTap.p95Microseconds))
        callback_p99_approx_us: \(format(runtime.eventTap.p99Microseconds))
        callback_maximum_us: \(format(runtime.eventTap.maximumMicroseconds))
        disabled_by_timeout: \(runtime.tapDisabledByTimeoutCount)
        disabled_by_user_input: \(runtime.tapDisabledByUserInputCount)
        jostle_synthetic_callbacks: \(runtime.jostleSyntheticEventCount)

        Smoothing Timer
        tick_samples: \(runtime.smoothingTick.sampleCount)
        tick_average_us: \(format(runtime.smoothingTick.averageMicroseconds))
        tick_p95_approx_us: \(format(runtime.smoothingTick.p95Microseconds))
        tick_p99_approx_us: \(format(runtime.smoothingTick.p99Microseconds))
        tick_maximum_us: \(format(runtime.smoothingTick.maximumMicroseconds))

        Input Configuration
        enabled: \(yesNo(input.isEnabled))
        schema_version: \(input.schemaVersion)
        scroll_profiles: \(input.scrollProfiles.count)
        enabled_scroll_profiles: \(enabledProfiles)
        exact_mouse_rules: \(exactMouseRules)
        exact_trackpad_rules: \(exactTrackpadRules)
        exact_unknown_rules: \(exactUnknownRules)
        custom_button_mappings: \(customButtonCount)
        universal_back_forward: \(yesNo(input.universalBackForward))
        reverse_mouse_scrolling: \(yesNo(input.reverseMouseScrolling))
        reverse_trackpad_scrolling: \(yesNo(input.reverseTrackpadScrolling))
        battery_display_mode: \(input.batteryDisplayMode.rawValue)

        Connected Device Inventory
        mice: \(context.connectedDeviceCounts[.mouse, default: 0])
        trackpads: \(context.connectedDeviceCounts[.trackpad, default: 0])
        unknown: \(context.connectedDeviceCounts[.unknown, default: 0])

        Other Configuration
        application_override_count: \(settings.applicationRules.count)
        window_controls_default: \(yesNo(settings.windowControlsEnabledByDefault))
        focus_follows_pointer_default: \(yesNo(settings.focusFollowsPointerEnabledByDefault))
        keep_awake_at_launch: \(yesNo(settings.keepAwakeActivateAtLaunch))
        known_input_utility_conflicts: \(conflicts)
        """
    }

    private static var architecture: String {
#if arch(arm64)
        "arm64"
#elseif arch(x86_64)
        "x86_64"
#else
        "unknown"
#endif
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
