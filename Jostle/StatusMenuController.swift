import AppKit
import JostleCore

final class StatusMenuController: NSObject {
    private let settingsStore: SettingsStore
    private let eventTapController: EventTapController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var recentApplication: RunningApplicationInfo?
    private var overallDisabled = false
    private var accessibilityAvailable = true

    init(settingsStore: SettingsStore, eventTapController: EventTapController) {
        self.settingsStore = settingsStore
        self.eventTapController = eventTapController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.autoenablesItems = false
        statusItem.menu = menu
        let image = NSImage(named: "MenuIcon")
            ?? NSImage(systemSymbolName: "rectangle.on.rectangle.angled", accessibilityDescription: "Jostle")
        image?.isTemplate = true
        statusItem.button?.image = image
        refresh()
    }

    func setRecentApplication(_ application: RunningApplicationInfo) {
        recentApplication = application
        refresh()
    }

    func setAccessibilityAvailable(_ available: Bool) {
        accessibilityAvailable = available
        refresh()
    }

    func refresh() {
        let settings = settingsStore.settings
        let model = MenuPolicy.model(for: MenuModelInput(
            modifiers: settings.modifiers,
            bringWindowToFront: settings.bringWindowToFront,
            middleClickResize: settings.middleClickResize,
            resizeOnly: settings.resizeOnly,
            overallDisabled: overallDisabled,
            recentApplicationKey: recentApplication?.key,
            recentApplicationName: recentApplication?.name,
            disabledApplications: settings.excludedApplications
        ))

        menu.removeAllItems()
        menu.addItem(item(from: model.application))
        if !accessibilityAvailable {
            let permissionItem = NSMenuItem(title: "Accessibility Access Required", action: nil, keyEquivalent: "")
            permissionItem.isEnabled = false
            menu.addItem(permissionItem)
        }
        menu.addItem(.separator())

        let disabledItem = item(
            from: model.overallDisabled,
            action: #selector(toggleOverallDisabled(_:))
        )
        menu.addItem(disabledItem)
        menu.addItem(.separator())

        for modifier in model.modifiers {
            let menuItem = item(from: modifier, action: #selector(toggleModifier(_:)))
            menuItem.representedObject = modifier.id
            menu.addItem(menuItem)
        }
        menu.addItem(.separator())

        for feature in model.features {
            let menuItem = item(from: feature, action: #selector(toggleFeature(_:)))
            menuItem.representedObject = feature.id
            menu.addItem(menuItem)
        }
        menu.addItem(.separator())

        let recentItem = NSMenuItem(
            title: model.recentApplication.title,
            action: #selector(excludeRecentApplication(_:)),
            keyEquivalent: ""
        )
        recentItem.target = self
        recentItem.isEnabled = model.recentApplication.enabled
        recentItem.representedObject = model.recentApplication.key
        menu.addItem(recentItem)

        let exclusionsItem = NSMenuItem(title: "Re-enable for", action: nil, keyEquivalent: "")
        exclusionsItem.isEnabled = model.disabledApplications.enabled
        let exclusionsMenu = NSMenu()
        exclusionsMenu.autoenablesItems = false
        for application in model.disabledApplications.items {
            let menuItem = NSMenuItem(
                title: application.title,
                action: #selector(includeApplication(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = application.key
            exclusionsMenu.addItem(menuItem)
        }
        exclusionsItem.submenu = exclusionsMenu
        menu.addItem(exclusionsItem)
        menu.addItem(.separator())

        menu.addItem(item(from: model.reset, action: #selector(reset(_:))))
        menu.addItem(item(from: model.exit, action: #selector(exit(_:))))
    }

    private func item(from model: MenuItemModel, action: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: model.title, action: action, keyEquivalent: "")
        item.target = action == nil ? nil : self
        item.state = model.checked ? .on : .off
        item.isEnabled = model.enabled
        return item
    }

    @objc private func toggleOverallDisabled(_ sender: NSMenuItem) {
        overallDisabled.toggle()
        eventTapController.setEnabled(!overallDisabled)
        refresh()
    }

    @objc private func toggleModifier(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let modifier = Self.modifier(for: identifier) else {
            return
        }
        settingsStore.update { settings in
            settings.setModifier(modifier, enabled: !settings.modifiers.contains(modifier))
        }
        refresh()
    }

    @objc private func toggleFeature(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        settingsStore.update { settings in
            switch identifier {
            case "bringWindowToFront":
                settings.bringWindowToFront.toggle()
            case "middleClickResize":
                settings.middleClickResize.toggle()
            case "resizeOnly":
                settings.resizeOnly.toggle()
            default:
                break
            }
        }
        refresh()
    }

    @objc private func excludeRecentApplication(_ sender: NSMenuItem) {
        guard let recentApplication,
              sender.representedObject as? String == recentApplication.key else {
            return
        }
        settingsStore.update { settings in
            settings.setApplicationExcluded(
                key: recentApplication.key,
                displayName: recentApplication.name,
                excluded: true
            )
        }
        refresh()
    }

    @objc private func includeApplication(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        settingsStore.update { settings in
            settings.setApplicationExcluded(key: key, displayName: nil, excluded: false)
        }
        refresh()
    }

    @objc private func reset(_ sender: NSMenuItem) {
        settingsStore.reset()
        overallDisabled = false
        eventTapController.setEnabled(true)
        refresh()
    }

    @objc private func exit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    private static func modifier(for identifier: String) -> Modifier? {
        switch identifier {
        case "option": return .option
        case "command": return .command
        case "control": return .control
        case "shift": return .shift
        case "function": return .function
        default: return nil
        }
    }
}
