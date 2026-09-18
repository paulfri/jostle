import Foundation
import JostleCore
import XCTest
@testable import Jostle

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "fm.pau.jostle.settings-tests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMissingOrInvalidDataUsesDefaultsWithoutWriting() {
        let missingStore = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(missingStore.settings, .defaults)
        XCTAssertNil(userDefaults.data(forKey: SettingsStore.storageKey))

        userDefaults.set(Data("not-json".utf8), forKey: SettingsStore.storageKey)
        let invalidStore = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(invalidStore.settings, .defaults)
        XCTAssertEqual(userDefaults.data(forKey: SettingsStore.storageKey), Data("not-json".utf8))
    }

    func testUpdatePersistsOneTypedSettingsDocument() {
        let store = SettingsStore(userDefaults: userDefaults)
        store.update { settings in
            settings.modifiers = [.option, .shift]
            settings.bringWindowToFront = true
            settings.middleClickResize = true
            settings.resizeOnly = true
            settings.setWindowControls(
                .disabled,
                forApplicationKey: "com.example.Game",
                displayName: "Game"
            )
            settings.setFocusFollowsPointer(
                .enabled,
                forApplicationKey: "com.example.Game",
                displayName: "Game"
            )
        }

        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).settings, store.settings)
        XCTAssertEqual(
            store.settings.applicationRules["com.example.Game"],
            ApplicationRule(
                displayName: "Game",
                windowControls: .disabled,
                focusFollowsPointer: .enabled
            )
        )
        let persistedKeys = Set(userDefaults.persistentDomain(forName: suiteName)?.keys.map { $0 } ?? [])
        XCTAssertEqual(persistedKeys, [SettingsStore.storageKey])
    }

    func testResetReplacesSettingsWithDefaults() {
        let store = SettingsStore(userDefaults: userDefaults)
        store.update { $0.resizeOnly = true }
        store.reset()

        XCTAssertEqual(store.settings, .defaults)
        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).settings, .defaults)
    }

    func testLinearMouseMigrationImportsContextualScrollBehavior() throws {
        let data = Data(#"""
        {
          "schemes": [
            {
              "buttons": { "universalBackForward": true },
              "if": { "device": { "category": "mouse" } },
              "scrolling": { "reverse": true }
            },
            {
              "if": [
                { "app": "com.apple.Safari", "device": { "category": "mouse" } },
                { "app": "com.apple.mail", "device": { "category": "mouse" } }
              ],
              "scrolling": {
                "smoothed": {
                  "preset": "linear", "speed": 0.5,
                  "acceleration": 0, "inertia": 0.3, "bouncing": true
                }
              }
            },
            {
              "if": {
                "device": {
                  "category": "mouse", "productName": "MX Master 3S",
                  "productID": "0xb034", "vendorID": "0x46d",
                  "serialNumber": "D6C79C59"
                }
              },
              "scrolling": {
                "smoothed": {
                  "vertical": {
                    "enabled": true, "preset": "easeInOut", "response": 0.68,
                    "speed": 1.02, "acceleration": 1.1, "inertia": 0.74
                  }
                }
              }
            },
            {
              "if": { "processName": "eqgame.exe" },
              "scrolling": { "distance": 1, "reverse": true, "smoothed": { "enabled": false } }
            }
          ]
        }
        """#.utf8)
        let mouse = PointingDeviceInfo(
            id: "hid-mx-master",
            displayName: "MX Master 3S",
            category: .mouse,
            registryID: 1,
            vendorID: 0x046d,
            productID: 0xb034,
            serialNumber: "D6C79C59"
        )

        let result = try LinearMouseMigration.importedInput(
            from: data,
            pointingDevices: [mouse]
        )

        XCTAssertEqual(result.settings.schemaVersion, 2)
        XCTAssertTrue(result.settings.universalBackForward)
        XCTAssertTrue(result.requiresDeviceInventory)
        XCTAssertFalse(result.hasUnresolvedExactDevice)
        XCTAssertEqual(result.settings.scrollProfiles.count, 4)
        XCTAssertEqual(
            result.settings.scrollProfiles[1].match.applicationBundleIdentifiers,
            ["com.apple.Safari", "com.apple.mail"]
        )
        XCTAssertEqual(result.settings.scrollProfiles[1].vertical.smoothing?.preset, .linear)
        XCTAssertEqual(result.settings.scrollProfiles[2].match.deviceKey, "hid-mx-master")
        XCTAssertEqual(result.settings.scrollProfiles[2].match.deviceDisplayName, "MX Master 3S")
        XCTAssertEqual(result.settings.scrollProfiles[2].vertical.smoothing?.response, 0.68)
        XCTAssertNil(result.settings.scrollProfiles[2].horizontal.smoothing)
        XCTAssertEqual(result.settings.scrollProfiles[3].match.processNames, ["eqgame.exe"])
        XCTAssertEqual(result.settings.scrollProfiles[3].vertical.distance, .lines(1))
        XCTAssertEqual(result.settings.scrollProfiles[3].vertical.smoothing?.enabled, false)
    }

    func testLinearMouseMigrationLeavesExactDeviceUnresolvedWhenHardwareIdentityDiffers() throws {
        let data = Data(#"""
        {
          "schemes": [{
            "if": {
              "device": {
                "category": "mouse", "productName": "MX Master 3S",
                "productID": "0xb034", "vendorID": "0x46d",
                "serialNumber": "expected-serial"
              }
            },
            "scrolling": { "reverse": true }
          }]
        }
        """#.utf8)
        let otherMouse = PointingDeviceInfo(
            id: "other-mouse",
            displayName: "MX Master 3S",
            category: .mouse,
            registryID: 2,
            vendorID: 0x046d,
            productID: 0xb034,
            serialNumber: "different-serial"
        )

        let result = try LinearMouseMigration.importedInput(
            from: data,
            pointingDevices: [otherMouse]
        )

        XCTAssertTrue(result.requiresDeviceInventory)
        XCTAssertTrue(result.hasUnresolvedExactDevice)
        XCTAssertTrue(result.settings.scrollProfiles.isEmpty)
    }
}
