import Foundation
import XCTest
@testable import JostleCore

final class MenuModelTests: XCTestCase {
    func testDefaultsProduceCompleteEnabledModel() {
        let model = MenuPolicy.model(for: input(modifiers: [.control, .command]))

        XCTAssertEqual(model.application, item("application", "Jostle", checked: false, enabled: false))
        XCTAssertEqual(model.overallDisabled, item("overallDisabled", "Disabled", checked: false))
        XCTAssertEqual(model.modifiers.map(\.id), ["option", "command", "control", "shift", "function"])
        XCTAssertEqual(model.modifiers.map(\.checked), [false, true, true, false, false])
        XCTAssertTrue(model.modifiers.allSatisfy(\.enabled))
        XCTAssertEqual(model.features.map(\.checked), [false, false, false])
        XCTAssertEqual(model.recentApplication, RecentApplicationMenuModel(
            title: "Disable for",
            enabled: false,
            key: nil
        ))
        XCTAssertEqual(model.disabledApplications, DisabledApplicationsMenuModel(enabled: false, items: []))
        XCTAssertEqual(model.reset, item("reset", "Reset to Defaults", checked: false))
        XCTAssertEqual(model.exit, item("exit", "Exit", checked: false))
    }

    func testEveryExposedModifierMapsDirectlyToItsMenuItem() {
        let mappings: [(Modifier, String)] = [
            (.option, "option"),
            (.command, "command"),
            (.control, "control"),
            (.shift, "shift"),
            (.function, "function")
        ]

        for (modifier, identifier) in mappings {
            let model = MenuPolicy.model(for: input(modifiers: [modifier, .capsLock]))
            XCTAssertEqual(model.modifiers.filter(\.checked).map(\.id), [identifier])
        }
    }

    func testEveryFeatureCombinationAndOverallDisableState() {
        for bits in 0..<8 {
            for overallDisabled in [false, true] {
                let bringToFront = bits & 1 != 0
                let middleClick = bits & 2 != 0
                let resizeOnly = bits & 4 != 0
                let model = MenuPolicy.model(for: input(
                    bringWindowToFront: bringToFront,
                    middleClickResize: middleClick,
                    resizeOnly: resizeOnly,
                    overallDisabled: overallDisabled,
                    recentApplicationKey: "com.example.game",
                    recentApplicationName: "Example Game"
                ))

                XCTAssertEqual(model.features.map(\.checked), [bringToFront, middleClick, resizeOnly])
                XCTAssertEqual(model.features.map(\.enabled), [!overallDisabled, !overallDisabled, true])
                XCTAssertEqual(model.modifiers.map(\.enabled), Array(repeating: !overallDisabled, count: 5))
                XCTAssertEqual(model.overallDisabled.checked, overallDisabled)
                XCTAssertTrue(model.recentApplication.enabled)
                XCTAssertTrue(model.reset.enabled)
                XCTAssertTrue(model.exit.enabled)
            }
        }
    }

    func testRecentApplicationTitleFallbackAndExclusionState() {
        let noRecent = MenuPolicy.model(for: input(
            recentApplicationKey: nil,
            recentApplicationName: "Ignored"
        ))
        XCTAssertEqual(noRecent.recentApplication.title, "Disable for")
        XCTAssertFalse(noRecent.recentApplication.enabled)
        XCTAssertNil(noRecent.recentApplication.key)

        let named = MenuPolicy.model(for: input(
            recentApplicationKey: "com.example.game",
            recentApplicationName: "Example Game"
        ))
        XCTAssertEqual(named.recentApplication.title, "Disable for Example Game")
        XCTAssertTrue(named.recentApplication.enabled)

        let fallback = MenuPolicy.model(for: input(
            recentApplicationKey: "com.example.game",
            recentApplicationName: "",
            disabledApplications: ["com.example.game": "Example Game"]
        ))
        XCTAssertEqual(fallback.recentApplication.title, "Disable for com.example.game")
        XCTAssertFalse(fallback.recentApplication.enabled)
        XCTAssertEqual(fallback.recentApplication.key, "com.example.game")
    }

    func testDisabledApplicationsHaveStableVisibleOrdering() {
        let applications = [
            "z.bundle": "beta",
            "b.bundle": "Alpha",
            "a.bundle": "Alpha",
            "c.bundle": "alpha"
        ]
        let expected = ["a.bundle", "b.bundle", "c.bundle", "z.bundle"]

        for insertionOrder in [
            Array(applications.keys),
            Array(applications.keys.reversed()),
            ["z.bundle", "c.bundle", "b.bundle", "a.bundle"]
        ] {
            var reordered: [String: String] = [:]
            for key in insertionOrder {
                reordered[key] = applications[key]
            }
            let model = MenuPolicy.model(for: input(disabledApplications: reordered))
            XCTAssertEqual(model.disabledApplications.items.map(\.key), expected)
            XCTAssertTrue(model.disabledApplications.enabled)
        }
    }

    func testModelEncodesToNormalizedDictionaryShape() throws {
        let model = MenuPolicy.model(for: input(
            modifiers: [.control, .command],
            recentApplicationKey: "com.example.game",
            recentApplicationName: "Example Game",
            disabledApplications: ["com.example.other": "Other"]
        ))
        let data = try JSONEncoder().encode(model)
        let dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(dictionary.keys), [
            "application",
            "overallDisabled",
            "modifiers",
            "features",
            "recentApplication",
            "disabledApplications",
            "reset",
            "exit"
        ])
        XCTAssertEqual((dictionary["modifiers"] as? [[String: Any]])?.count, 5)
        XCTAssertEqual((dictionary["features"] as? [[String: Any]])?.count, 3)
    }

    private func input(
        modifiers: Set<Modifier> = [],
        bringWindowToFront: Bool = false,
        middleClickResize: Bool = false,
        resizeOnly: Bool = false,
        overallDisabled: Bool = false,
        recentApplicationKey: String? = nil,
        recentApplicationName: String? = nil,
        disabledApplications: [String: String] = [:]
    ) -> MenuModelInput {
        MenuModelInput(
            modifiers: modifiers,
            bringWindowToFront: bringWindowToFront,
            middleClickResize: middleClickResize,
            resizeOnly: resizeOnly,
            overallDisabled: overallDisabled,
            recentApplicationKey: recentApplicationKey,
            recentApplicationName: recentApplicationName,
            disabledApplications: disabledApplications
        )
    }

    private func item(
        _ id: String,
        _ title: String,
        checked: Bool,
        enabled: Bool = true
    ) -> MenuItemModel {
        MenuItemModel(id: id, title: title, checked: checked, enabled: enabled)
    }
}
