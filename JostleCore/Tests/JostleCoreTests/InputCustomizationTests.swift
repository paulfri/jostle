import XCTest
@testable import JostleCore

final class InputCustomizationTests: XCTestCase {
    func testDefaultsAreOptInAndPreserveNativeBehavior() {
        let settings = InputCustomizationSettings.defaults

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
            ]
        )

        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(InputCustomizationSettings.self, from: data), settings)
    }
}
