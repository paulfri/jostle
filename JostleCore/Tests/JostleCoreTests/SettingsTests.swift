import Foundation
import XCTest
@testable import JostleCore

final class SettingsTests: XCTestCase {
    func testDefaultsAreImmediatelyUsable() {
        XCTAssertEqual(JostleSettings.defaults.modifiers, [.control])
        XCTAssertFalse(JostleSettings.defaults.bringWindowToFront)
        XCTAssertFalse(JostleSettings.defaults.middleClickResize)
        XCTAssertFalse(JostleSettings.defaults.resizeOnly)
        XCTAssertTrue(JostleSettings.defaults.resizeFeedbackEnabled)
        XCTAssertTrue(JostleSettings.defaults.doubleClickActionsEnabled)
        XCTAssertTrue(JostleSettings.defaults.snapEnabled)
        XCTAssertEqual(JostleSettings.defaults.snapGap, 8)
        XCTAssertEqual(JostleSettings.defaults.snapScreenMargin, 0)
        XCTAssertTrue(JostleSettings.defaults.windowControlsEnabledByDefault)
        XCTAssertFalse(JostleSettings.defaults.focusFollowsPointerEnabledByDefault)
        XCTAssertEqual(JostleSettings.defaults.focusFollowsPointerDelay, 0.1)
        XCTAssertEqual(JostleSettings.defaults.applicationRules, [:])
        XCTAssertFalse(JostleSettings.defaults.hasEnabledFocusFollowsPointerRule)
        XCTAssertEqual(JostleSettings.defaults.keepAwakeDefaultDuration, .indefinitely)
        XCTAssertFalse(JostleSettings.defaults.keepAwakeActivateAtLaunch)
        XCTAssertFalse(JostleSettings.defaults.keepAwakeActivateOnLeftClick)
        XCTAssertFalse(JostleSettings.defaults.keepAwakeAllowDisplaySleep)
        XCTAssertFalse(JostleSettings.defaults.keepAwakeAllowSleepWhenLocked)
        XCTAssertFalse(JostleSettings.defaults.keepAwakeDeactivateOnBattery)
        XCTAssertFalse(JostleSettings.defaults.keepAwakeDimWhenInactive)
        XCTAssertEqual(JostleSettings.defaults.keepAwakeIndicatorStyle, .normal)
        XCTAssertTrue(JostleSettings.defaults.keepAwakeUseImprovedTimer)
        XCTAssertNil(JostleSettings.defaults.keepAwakeShortcut)
    }

    func testSettingsRoundTripThroughCodable() throws {
        let settings = JostleSettings(
            modifiers: [.option, .shift],
            bringWindowToFront: true,
            middleClickResize: true,
            resizeOnly: true,
            resizeFeedbackEnabled: false,
            doubleClickActionsEnabled: false,
            snapEnabled: false,
            snapGap: 14,
            snapScreenMargin: 6,
            windowControlsEnabledByDefault: false,
            focusFollowsPointerEnabledByDefault: true,
            focusFollowsPointerDelay: 0.5,
            applicationRules: [
                "com.example.Game": ApplicationRule(
                    displayName: "Game",
                    windowControls: .enabled,
                    focusFollowsPointer: .disabled
                )
            ],
            keepAwakeDefaultDuration: .fourHours,
            keepAwakeActivateAtLaunch: true,
            keepAwakeActivateOnLeftClick: true,
            keepAwakeAllowDisplaySleep: true,
            keepAwakeAllowSleepWhenLocked: true,
            keepAwakeDeactivateOnBattery: true,
            keepAwakeDimWhenInactive: true,
            keepAwakeIndicatorStyle: .coloredGreen,
            keepAwakeUseImprovedTimer: false,
            keepAwakeShortcut: GlobalShortcut(keyCode: 37, modifiers: [.control, .command])
        )

        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(JostleSettings.self, from: data), settings)
    }

    func testOlderDocumentsMigrateExclusionsToDisabledAppRules() throws {
        let data = Data("""
        {
          "modifiers": ["option"],
          "bringWindowToFront": true,
          "middleClickResize": false,
          "resizeOnly": false,
          "excludedApplications": {"com.example.Game": "Game"}
        }
        """.utf8)

        let settings = try JSONDecoder().decode(JostleSettings.self, from: data)

        XCTAssertEqual(settings.modifiers, [.option])
        XCTAssertTrue(settings.bringWindowToFront)
        XCTAssertTrue(settings.resizeFeedbackEnabled)
        XCTAssertTrue(settings.doubleClickActionsEnabled)
        XCTAssertTrue(settings.snapEnabled)
        XCTAssertEqual(settings.snapGap, 8)
        XCTAssertEqual(settings.snapScreenMargin, 0)
        XCTAssertTrue(settings.windowControlsEnabledByDefault)
        XCTAssertFalse(settings.focusFollowsPointerEnabledByDefault)
        XCTAssertEqual(settings.focusFollowsPointerDelay, 0.1)
        XCTAssertEqual(
            settings.applicationRules["com.example.Game"],
            ApplicationRule(
                displayName: "Game",
                windowControls: .disabled,
                focusFollowsPointer: .disabled
            )
        )
        XCTAssertFalse(settings.windowControlsEnabled(forApplicationKey: "com.example.Game"))
        XCTAssertFalse(settings.focusFollowsPointerEnabled(forApplicationKey: "com.example.Game"))
        XCTAssertEqual(settings.keepAwakeDefaultDuration, .indefinitely)
        XCTAssertFalse(settings.keepAwakeActivateAtLaunch)
        XCTAssertFalse(settings.keepAwakeActivateOnLeftClick)
        XCTAssertFalse(settings.keepAwakeAllowDisplaySleep)
        XCTAssertFalse(settings.keepAwakeAllowSleepWhenLocked)
        XCTAssertFalse(settings.keepAwakeDeactivateOnBattery)
        XCTAssertFalse(settings.keepAwakeDimWhenInactive)
        XCTAssertEqual(settings.keepAwakeIndicatorStyle, .normal)
        XCTAssertTrue(settings.keepAwakeUseImprovedTimer)
        XCTAssertNil(settings.keepAwakeShortcut)
    }

    func testApplicationRulesResolveAgainstIndependentDefaults() {
        var settings = JostleSettings.defaults
        settings.setWindowControls(
            .disabled,
            forApplicationKey: "com.example.Game",
            displayName: "Game"
        )
        settings.setFocusFollowsPointer(
            .enabled,
            forApplicationKey: "com.example.Game",
            displayName: "Renamed Game"
        )

        XCTAssertFalse(settings.windowControlsEnabled(forApplicationKey: "com.example.Game"))
        XCTAssertTrue(settings.focusFollowsPointerEnabled(forApplicationKey: "com.example.Game"))
        XCTAssertEqual(settings.applicationRules["com.example.Game"]?.displayName, "Renamed Game")
        XCTAssertTrue(settings.windowControlsEnabled(forApplicationKey: "com.example.Editor"))
        XCTAssertFalse(settings.focusFollowsPointerEnabled(forApplicationKey: "com.example.Editor"))
        XCTAssertTrue(settings.hasEnabledFocusFollowsPointerRule)

        settings.windowControlsEnabledByDefault = false
        settings.focusFollowsPointerEnabledByDefault = true
        settings.setWindowControls(
            .useDefault,
            forApplicationKey: "com.example.Game",
            displayName: "Game"
        )
        settings.setFocusFollowsPointer(
            .useDefault,
            forApplicationKey: "com.example.Game",
            displayName: "Game"
        )

        XCTAssertFalse(settings.windowControlsEnabled(forApplicationKey: "com.example.Game"))
        XCTAssertTrue(settings.focusFollowsPointerEnabled(forApplicationKey: "com.example.Game"))
    }

    func testApplicationRuleMutationsAreIdempotent() {
        var settings = JostleSettings.defaults
        settings.addApplicationRule(key: "eqgame.exe", displayName: "EverQuest")
        settings.addApplicationRule(key: "eqgame.exe", displayName: "Ignored Rename")
        XCTAssertEqual(
            settings.applicationRules["eqgame.exe"],
            ApplicationRule(displayName: "EverQuest")
        )

        settings.removeApplicationRule(key: "eqgame.exe")
        settings.removeApplicationRule(key: "eqgame.exe")
        XCTAssertEqual(settings.applicationRules, [:])
    }

    func testMutationsAreTypedAndIdempotent() {
        var settings = JostleSettings.defaults
        settings.setModifier(.shift, enabled: true)
        settings.setModifier(.shift, enabled: true)
        settings.setModifier(.control, enabled: false)
        XCTAssertEqual(settings.modifiers, [.shift])
    }

    func testLastSelectedModifierCannotBeRemoved() {
        var settings = JostleSettings.defaults

        settings.setModifier(.control, enabled: false)

        XCTAssertEqual(settings.modifiers, [.control])
    }

    func testApplicationIdentityUsesNonemptyBundleThenName() {
        XCTAssertEqual(
            ApplicationIdentity.key(bundleIdentifier: "com.example.Game", localizedName: "Game"),
            "com.example.Game"
        )
        XCTAssertEqual(
            ApplicationIdentity.key(bundleIdentifier: "", localizedName: "eqgame.exe"),
            "eqgame.exe"
        )
        XCTAssertNil(ApplicationIdentity.key(bundleIdentifier: nil, localizedName: ""))
    }
}
