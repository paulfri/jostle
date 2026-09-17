import Foundation

public struct MenuItemModel: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var checked: Bool
    public var enabled: Bool

    public init(id: String, title: String, checked: Bool, enabled: Bool) {
        self.id = id
        self.title = title
        self.checked = checked
        self.enabled = enabled
    }
}

public struct RecentApplicationMenuModel: Codable, Equatable, Sendable {
    public var title: String
    public var enabled: Bool
    public var key: String?

    public init(title: String, enabled: Bool, key: String?) {
        self.title = title
        self.enabled = enabled
        self.key = key
    }
}

public struct DisabledApplicationMenuItem: Codable, Equatable, Sendable {
    public var key: String
    public var title: String

    public init(key: String, title: String) {
        self.key = key
        self.title = title
    }
}

public struct DisabledApplicationsMenuModel: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var items: [DisabledApplicationMenuItem]

    public init(enabled: Bool, items: [DisabledApplicationMenuItem]) {
        self.enabled = enabled
        self.items = items
    }
}

public struct MenuModelInput: Equatable, Sendable {
    public var modifiers: Set<Modifier>
    public var bringWindowToFront: Bool
    public var middleClickResize: Bool
    public var resizeOnly: Bool
    public var overallDisabled: Bool
    public var recentApplicationKey: String?
    public var recentApplicationName: String?
    public var disabledApplications: [String: String]

    public init(
        modifiers: Set<Modifier>,
        bringWindowToFront: Bool,
        middleClickResize: Bool,
        resizeOnly: Bool,
        overallDisabled: Bool,
        recentApplicationKey: String?,
        recentApplicationName: String?,
        disabledApplications: [String: String]
    ) {
        self.modifiers = modifiers
        self.bringWindowToFront = bringWindowToFront
        self.middleClickResize = middleClickResize
        self.resizeOnly = resizeOnly
        self.overallDisabled = overallDisabled
        self.recentApplicationKey = recentApplicationKey
        self.recentApplicationName = recentApplicationName
        self.disabledApplications = disabledApplications
    }
}

public struct MenuModel: Codable, Equatable, Sendable {
    public var application: MenuItemModel
    public var overallDisabled: MenuItemModel
    public var modifiers: [MenuItemModel]
    public var features: [MenuItemModel]
    public var recentApplication: RecentApplicationMenuModel
    public var disabledApplications: DisabledApplicationsMenuModel
    public var reset: MenuItemModel
    public var exit: MenuItemModel

    public init(
        application: MenuItemModel,
        overallDisabled: MenuItemModel,
        modifiers: [MenuItemModel],
        features: [MenuItemModel],
        recentApplication: RecentApplicationMenuModel,
        disabledApplications: DisabledApplicationsMenuModel,
        reset: MenuItemModel,
        exit: MenuItemModel
    ) {
        self.application = application
        self.overallDisabled = overallDisabled
        self.modifiers = modifiers
        self.features = features
        self.recentApplication = recentApplication
        self.disabledApplications = disabledApplications
        self.reset = reset
        self.exit = exit
    }
}

public enum MenuPolicy {
    public static func model(for input: MenuModelInput) -> MenuModel {
        let primaryControlsEnabled = !input.overallDisabled
        let modifierDefinitions: [(id: String, title: String, modifier: Modifier)] = [
            (id: "option", title: "Option", modifier: .option),
            (id: "command", title: "Command", modifier: .command),
            (id: "control", title: "Control", modifier: .control),
            (id: "shift", title: "Shift", modifier: .shift),
            (id: "function", title: "Function", modifier: .function)
        ]
        let modifiers = modifierDefinitions.map { definition in
            MenuItemModel(
                id: definition.id,
                title: definition.title,
                checked: input.modifiers.contains(definition.modifier),
                enabled: primaryControlsEnabled
            )
        }
        let features = [
            MenuItemModel(
                id: "bringWindowToFront",
                title: "Bring Window to Front",
                checked: input.bringWindowToFront,
                enabled: primaryControlsEnabled
            ),
            MenuItemModel(
                id: "middleClickResize",
                title: "Middle Click Resize",
                checked: input.middleClickResize,
                enabled: primaryControlsEnabled
            ),
            MenuItemModel(
                id: "resizeOnly",
                title: "Resize Only",
                checked: input.resizeOnly,
                enabled: true
            )
        ]
        let disabledItems = input.disabledApplications
            .map { DisabledApplicationMenuItem(key: $0.key, title: $0.value) }
            .sorted(by: disabledApplicationPrecedes)

        let recentKey = input.recentApplicationKey.flatMap { $0.isEmpty ? nil : $0 }
        let recentName = recentKey.map { key in
            input.recentApplicationName.flatMap { $0.isEmpty ? nil : $0 } ?? key
        }
        let recentTitle = recentName.map { "Disable for \($0)" } ?? "Disable for"
        let recentEnabled = recentKey.map { input.disabledApplications[$0] == nil } ?? false

        return MenuModel(
            application: MenuItemModel(id: "application", title: "Jostle", checked: false, enabled: false),
            overallDisabled: MenuItemModel(
                id: "overallDisabled",
                title: "Disabled",
                checked: input.overallDisabled,
                enabled: true
            ),
            modifiers: modifiers,
            features: features,
            recentApplication: RecentApplicationMenuModel(
                title: recentTitle,
                enabled: recentEnabled,
                key: recentKey
            ),
            disabledApplications: DisabledApplicationsMenuModel(
                enabled: !disabledItems.isEmpty,
                items: disabledItems
            ),
            reset: MenuItemModel(id: "reset", title: "Reset to Defaults", checked: false, enabled: true),
            exit: MenuItemModel(id: "exit", title: "Exit", checked: false, enabled: true)
        )
    }

    private static func disabledApplicationPrecedes(
        _ left: DisabledApplicationMenuItem,
        _ right: DisabledApplicationMenuItem
    ) -> Bool {
        let caseInsensitive = left.title.caseInsensitiveCompare(right.title)
        if caseInsensitive != .orderedSame {
            return caseInsensitive == .orderedAscending
        }
        let exact = left.title.compare(right.title)
        if exact != .orderedSame {
            return exact == .orderedAscending
        }
        return left.key.compare(right.key) == .orderedAscending
    }
}
