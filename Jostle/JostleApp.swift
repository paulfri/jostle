import SwiftUI

@main
struct JostleApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            JostleSettingsView(settingsStore: appDelegate.settingsStore)
        }
    }
}
