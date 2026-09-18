import Combine
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
        let service = service ?? ServiceManagementLoginItemService()
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
}

private final class ServiceManagementLoginItemService: LoginItemServicing {
    var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        @unknown default:
            false
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
