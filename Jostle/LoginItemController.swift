import Combine
import Darwin
import Foundation
import ServiceManagement

protocol LoginItemServicing: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var errorMessage: String?

    var onChange: (() -> Void)?

    private let service: LoginItemServicing

    init(service: LoginItemServicing? = nil) {
        let service = service ?? Self.makeService()
        self.service = service
        isEnabled = service.isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            try service.setEnabled(enabled)
        } catch {
            errorMessage = error.localizedDescription
        }
        isEnabled = service.isEnabled
        onChange?()
    }

    func refresh() {
        let currentValue = service.isEnabled
        guard currentValue != isEnabled else { return }
        isEnabled = currentValue
        onChange?()
    }

    func clearError() {
        errorMessage = nil
    }

    private static func makeService() -> LoginItemServicing {
        if #available(macOS 13.0, *) {
            return ServiceManagementLoginItemService()
        }
        return LaunchAgentLoginItemService()
    }
}

@available(macOS 13.0, *)
private final class ServiceManagementLoginItemService: LoginItemServicing {
    var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled, !isEnabled {
            try SMAppService.mainApp.register()
        } else if !enabled, isEnabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

private final class LaunchAgentLoginItemService: LoginItemServicing {
    private let fileManager: FileManager
    private let launchAgentURL: URL
    private let applicationURL: URL
    private let label: String

    init(
        fileManager: FileManager = .default,
        applicationURL: URL = Bundle.main.bundleURL
    ) {
        self.fileManager = fileManager
        self.applicationURL = applicationURL
        label = "\(Bundle.main.bundleIdentifier ?? "fm.pau.jostle").login-item"
        launchAgentURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    var isEnabled: Bool {
        fileManager.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try uninstall()
        }
    }

    private func install() throws {
        let directory = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let propertyList: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-g", applicationURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)

        try? runLaunchctl(["bootout", serviceTarget])
        do {
            try runLaunchctl(["bootstrap", domainTarget, launchAgentURL.path])
        } catch {
            try? fileManager.removeItem(at: launchAgentURL)
            throw error
        }
    }

    private func uninstall() throws {
        try? runLaunchctl(["bootout", serviceTarget])
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
        }
    }

    private var domainTarget: String {
        "gui/\(getuid())"
    }

    private var serviceTarget: String {
        "\(domainTarget)/\(label)"
    }

    private func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw LoginItemServiceError.launchctlFailed(detail: detail)
        }
    }
}

private enum LoginItemServiceError: LocalizedError {
    case launchctlFailed(detail: String?)

    var errorDescription: String? {
        switch self {
        case let .launchctlFailed(detail):
            if let detail, !detail.isEmpty {
                return "Couldn’t update Start at Login: \(detail)"
            }
            return "Couldn’t update Start at Login."
        }
    }
}
