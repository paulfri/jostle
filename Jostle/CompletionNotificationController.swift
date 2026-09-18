import UserNotifications

protocol KeepAwakeCompletionNotifying: AnyObject {
    func prepare()
    func notifyCompletion()
}

final class CompletionNotificationController: NSObject, KeepAwakeCompletionNotifying,
    UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    private var didRequestAuthorization = false

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func prepare() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyCompletion() {
        let content = UNMutableNotificationContent()
        content.title = "Keep-Awake Session Completed"
        content.body = "Your Mac can now sleep normally."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "keep-awake-completed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
