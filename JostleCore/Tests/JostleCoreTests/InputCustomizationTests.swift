import XCTest
@testable import JostleCore

final class InputCustomizationTests: XCTestCase {
    func testDefaultsAreOptInAndPreserveNativeBehavior() {
        let settings = InputCustomizationSettings.defaults

        XCTAssertEqual(settings.schemaVersion, 3)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.reverseScrolling(forDeviceKey: nil, category: .mouse))
        XCTAssertFalse(settings.reverseScrolling(forDeviceKey: nil, category: .trackpad))
        XCTAssertEqual(settings.action(forButtonNumber: 3), .systemDefault)
        XCTAssertEqual(settings.action(forButtonNumber: 4), .systemDefault)
        XCTAssertTrue(settings.allowsFocusFollowsPointer(forDeviceKey: nil, category: .mouse))
        XCTAssertTrue(settings.allowsFocusFollowsPointer(forDeviceKey: nil, category: .trackpad))
    }

    func testDeviceRulesOverrideCategoryDefaultsIndependently() {
        var settings = InputCustomizationSettings(
            reverseMouseScrolling: true,
            focusFollowsPointerForMouse: false
        )
        settings.setDeviceRule(
            key: "mouse-a",
            displayName: "Mouse A",
            category: .mouse,
            reverseScrolling: .disabled,
            focusFollowsPointer: .enabled
        )

        XCTAssertFalse(settings.reverseScrolling(forDeviceKey: "mouse-a", category: .mouse))
        XCTAssertTrue(settings.reverseScrolling(forDeviceKey: "mouse-b", category: .mouse))
        XCTAssertTrue(settings.allowsFocusFollowsPointer(forDeviceKey: "mouse-a", category: .mouse))
        XCTAssertFalse(settings.allowsFocusFollowsPointer(forDeviceKey: "mouse-b", category: .mouse))
    }

    func testUniversalBackForwardOnlyReplacesSystemDefaults() {
        var settings = InputCustomizationSettings(universalBackForward: true)

        XCTAssertEqual(settings.action(forButtonNumber: 3), .back)
        XCTAssertEqual(settings.action(forButtonNumber: 4), .forward)
        XCTAssertEqual(settings.action(forButtonNumber: 6), .systemDefault)

        settings.buttonFourAction = .moveWindow
        XCTAssertEqual(settings.action(forButtonNumber: 3), .moveWindow)
    }

    func testDeviceFocusGatesExistingApplicationPolicyOnlyWhenInputIsEnabled() {
        var settings = JostleSettings.defaults
        settings.focusFollowsPointerEnabledByDefault = true
        settings.inputCustomization.focusFollowsPointerForTrackpad = false

        XCTAssertTrue(settings.focusFollowsPointerEnabled(
            forApplicationKey: nil,
            deviceKey: nil,
            deviceCategory: .trackpad
        ))

        settings.inputCustomization.isEnabled = true
        XCTAssertFalse(settings.focusFollowsPointerEnabled(
            forApplicationKey: nil,
            deviceKey: nil,
            deviceCategory: .trackpad
        ))
        XCTAssertTrue(settings.focusFollowsPointerEnabled(
            forApplicationKey: nil,
            deviceKey: nil,
            deviceCategory: .mouse
        ))
    }

    func testPointerButtonGesturePinsActionUntilMatchingRelease() {
        XCTAssertEqual(
            PointerButtonGesturePolicy.intent(
                eventType: .mouseDown,
                buttonNumber: 3,
                configuredAction: .moveWindow,
                activeButtonNumber: nil,
                activeAction: nil
            ),
            .beginMove
        )
        XCTAssertEqual(
            PointerButtonGesturePolicy.intent(
                eventType: .mouseDragged,
                buttonNumber: 3,
                configuredAction: .systemDefault,
                activeButtonNumber: 3,
                activeAction: .moveWindow
            ),
            .continueMove
        )
        XCTAssertEqual(
            PointerButtonGesturePolicy.intent(
                eventType: .mouseDown,
                buttonNumber: 4,
                configuredAction: .resizeWindow,
                activeButtonNumber: 3,
                activeAction: .moveWindow
            ),
            .passThrough
        )
        XCTAssertEqual(
            PointerButtonGesturePolicy.intent(
                eventType: .mouseUp,
                buttonNumber: 3,
                configuredAction: .systemDefault,
                activeButtonNumber: 3,
                activeAction: .moveWindow
            ),
            .end
        )
    }

    func testPartialInputDocumentMigratesMissingFieldsToSafeDefaults() throws {
        let data = try XCTUnwrap("""
        {"isEnabled":true,"reverseMouseScrolling":true}
        """.data(using: .utf8))

        let settings = try JSONDecoder().decode(InputCustomizationSettings.self, from: data)

        XCTAssertEqual(settings.schemaVersion, 1)
        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(settings.reverseMouseScrolling)
        XCTAssertFalse(settings.reverseTrackpadScrolling)
        XCTAssertEqual(settings.buttonFourAction, .systemDefault)
        XCTAssertTrue(settings.focusFollowsPointerForTrackpad)
        XCTAssertTrue(settings.deviceRules.isEmpty)
    }

    func testLegacyScrollProfileDecodesWithEmptyExclusions() throws {
        let data = Data(#"""
        {
          "schemaVersion": 2,
          "scrollProfiles": [{
            "id": "legacy-profile",
            "name": "Mouse smoothing",
            "isEnabled": true,
            "match": {
              "deviceCategory": "mouse",
              "applicationBundleIdentifiers": [],
              "processNames": []
            },
            "vertical": {},
            "horizontal": {}
          }]
        }
        """#.utf8)

        let settings = try JSONDecoder().decode(InputCustomizationSettings.self, from: data)
        let match = try XCTUnwrap(settings.scrollProfiles.first?.match)

        XCTAssertEqual(settings.schemaVersion, 2)
        XCTAssertTrue(match.excludedApplicationBundleIdentifiers.isEmpty)
        XCTAssertTrue(match.excludedProcessNames.isEmpty)
    }

    func testScrollProfilesMergeByDeviceAndApplicationInDefinitionOrder() {
        let settings = InputCustomizationSettings(
            isEnabled: true,
            reverseMouseScrolling: true,
            scrollProfiles: [
                ScrollProfile(
                    name: "Apple apps",
                    match: ScrollProfileMatch(
                        deviceCategory: .mouse,
                        applicationBundleIdentifiers: ["com.apple.Safari"]
                    ),
                    vertical: ScrollAxisSettings(
                        smoothing: ScrollSmoothingSettings(
                            enabled: true,
                            preset: .linear,
                            speed: 0.5,
                            inertia: 0.3,
                            bouncing: true
                        )
                    )
                ),
                ScrollProfile(
                    name: "Safari bounce",
                    match: ScrollProfileMatch(
                        applicationBundleIdentifiers: ["com.apple.Safari"]
                    ),
                    vertical: ScrollAxisSettings(
                        smoothing: ScrollSmoothingSettings(bouncing: false)
                    )
                )
            ]
        )

        let resolved = ScrollProfileResolver.resolve(
            input: settings,
            deviceKey: "mouse-a",
            deviceCategory: .mouse,
            applicationBundleIdentifier: "com.apple.Safari",
            processName: "Safari"
        )

        XCTAssertTrue(resolved.vertical.reverse)
        XCTAssertEqual(resolved.vertical.smoothing?.preset, .linear)
        XCTAssertEqual(resolved.vertical.smoothing?.response, 0.45)
        XCTAssertEqual(resolved.vertical.smoothing?.speed, 0.5)
        XCTAssertEqual(resolved.vertical.smoothing?.acceleration, 1.2)
        XCTAssertEqual(resolved.vertical.smoothing?.inertia, 0.3)
        XCTAssertEqual(resolved.vertical.smoothing?.bouncing, false)
    }

    func testProfileExclusionsPreserveBaseReverseScrolling() {
        let settings = InputCustomizationSettings(
            reverseMouseScrolling: true,
            scrollProfiles: [
                ScrollProfile(
                    name: "Mouse smoothing",
                    match: ScrollProfileMatch(
                        deviceCategory: .mouse,
                        excludedProcessNames: ["eqgame.exe"]
                    ),
                    vertical: ScrollAxisSettings(
                        speed: 1.5,
                        smoothing: ScrollSmoothingSettings(enabled: true)
                    )
                )
            ]
        )

        let excluded = ScrollProfileResolver.resolve(
            input: settings,
            deviceKey: nil,
            deviceCategory: .mouse,
            applicationBundleIdentifier: nil,
            processName: "EQGAME.EXE"
        )
        let included = ScrollProfileResolver.resolve(
            input: settings,
            deviceKey: nil,
            deviceCategory: .mouse,
            applicationBundleIdentifier: nil,
            processName: "Finder"
        )

        XCTAssertTrue(excluded.vertical.reverse)
        XCTAssertEqual(excluded.vertical.speed, 0)
        XCTAssertNil(excluded.vertical.smoothing)
        XCTAssertTrue(included.vertical.reverse)
        XCTAssertEqual(included.vertical.speed, 1.5)
        XCTAssertNotNil(included.vertical.smoothing)
    }

    func testProfileExclusionWinsOverApplicationInclude() {
        let match = ScrollProfileMatch(
            applicationBundleIdentifiers: ["com.example.Game"],
            excludedApplicationBundleIdentifiers: ["com.example.game"]
        )

        XCTAssertFalse(match.matches(
            deviceKey: nil,
            deviceCategory: .mouse,
            applicationBundleIdentifier: "COM.EXAMPLE.GAME",
            processName: nil
        ))
    }

    func testProcessProfileCanDisableInheritedSmoothingAndSetLineDistance() {
        let settings = InputCustomizationSettings(
            scrollProfiles: [
                ScrollProfile(
                    name: "Mouse smoothing",
                    match: ScrollProfileMatch(deviceCategory: .mouse),
                    vertical: ScrollAxisSettings(
                        smoothing: ScrollSmoothingSettings(enabled: true)
                    )
                ),
                ScrollProfile(
                    name: "EverQuest",
                    match: ScrollProfileMatch(processNames: ["eqgame.exe"]),
                    vertical: ScrollAxisSettings(
                        distance: .lines(1),
                        smoothing: ScrollSmoothingSettings(enabled: false)
                    )
                )
            ]
        )

        let resolved = ScrollProfileResolver.resolve(
            input: settings,
            deviceKey: nil,
            deviceCategory: .mouse,
            applicationBundleIdentifier: nil,
            processName: "eqgame.exe"
        )

        XCTAssertEqual(resolved.vertical.distance, .lines(1))
        XCTAssertNil(resolved.vertical.smoothing)
    }

    func testInputCustomizationRoundTrips() throws {
        let settings = InputCustomizationSettings(
            isEnabled: true,
            reverseMouseScrolling: true,
            universalBackForward: true,
            buttonFourAction: .moveWindow,
            buttonFiveAction: .toggleKeepAwake,
            focusFollowsPointerForTrackpad: false,
            deviceRules: [
                "mouse-a": PointingDeviceRule(
                    displayName: "Mouse A",
                    category: .mouse,
                    reverseScrolling: .disabled,
                    focusFollowsPointer: .enabled
                )
            ],
            scrollProfiles: [
                ScrollProfile(
                    name: "Mouse smoothing",
                    match: ScrollProfileMatch(
                        deviceCategory: .mouse,
                        excludedApplicationBundleIdentifiers: ["com.example.Game"],
                        excludedProcessNames: ["eqgame.exe"]
                    ),
                    vertical: ScrollAxisSettings(
                        smoothing: ScrollSmoothingSettings(enabled: true, preset: .easeInOut)
                    )
                )
            ],
            batteryDisplayMode: .belowTwentyPercent
        )

        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(InputCustomizationSettings.self, from: data), settings)
    }
}
