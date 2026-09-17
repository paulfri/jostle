import Foundation
import XCTest
@testable import JostleCore

final class SettingsTests: XCTestCase {
    func testDefaultsAreImmediatelyUsable() {
        XCTAssertEqual(JostleSettings.defaults.modifiers, [.control, .command])
        XCTAssertFalse(JostleSettings.defaults.bringWindowToFront)
        XCTAssertFalse(JostleSettings.defaults.middleClickResize)
        XCTAssertFalse(JostleSettings.defaults.resizeOnly)
        XCTAssertEqual(JostleSettings.defaults.excludedApplications, [:])
    }

    func testSettingsRoundTripThroughCodable() throws {
        let settings = JostleSettings(
            modifiers: [.option, .shift],
            bringWindowToFront: true,
            middleClickResize: true,
            resizeOnly: true,
            excludedApplications: ["com.example.Game": "Game"]
        )

        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(JostleSettings.self, from: data), settings)
    }

    func testMutationsAreTypedAndIdempotent() {
        var settings = JostleSettings.defaults
        settings.setModifier(.shift, enabled: true)
        settings.setModifier(.shift, enabled: true)
        settings.setModifier(.control, enabled: false)
        XCTAssertEqual(settings.modifiers, [.command, .shift])

        settings.setApplicationExcluded(key: "com.example.Game", displayName: "Game", excluded: true)
        settings.setApplicationExcluded(key: "com.example.Game", displayName: "Renamed", excluded: true)
        XCTAssertEqual(settings.excludedApplications, ["com.example.Game": "Renamed"])

        settings.setApplicationExcluded(key: "com.example.Game", displayName: nil, excluded: false)
        settings.setApplicationExcluded(key: "com.example.Game", displayName: nil, excluded: false)
        XCTAssertEqual(settings.excludedApplications, [:])
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
