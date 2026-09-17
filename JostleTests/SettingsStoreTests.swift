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
            settings.setApplicationExcluded(
                key: "com.example.Game",
                displayName: "Game",
                excluded: true
            )
        }

        XCTAssertEqual(SettingsStore(userDefaults: userDefaults).settings, store.settings)
        XCTAssertEqual(store.settings.excludedApplications, ["com.example.Game": "Game"])
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
}
