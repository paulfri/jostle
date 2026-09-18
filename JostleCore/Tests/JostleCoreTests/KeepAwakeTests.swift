import Foundation
import XCTest
@testable import JostleCore

final class KeepAwakeTests: XCTestCase {
    func testPresetDurationsMatchMenuChoices() {
        XCTAssertEqual(KeepAwakeDurationPreset.allCases.map(\.title), [
            "Indefinitely",
            "10 Minutes",
            "30 Minutes",
            "1 Hour",
            "2 Hours",
            "4 Hours",
            "8 Hours",
            "12 Hours"
        ])
        XCTAssertNil(KeepAwakeDurationPreset.indefinitely.duration.seconds)
        XCTAssertEqual(KeepAwakeDurationPreset.tenMinutes.duration.seconds, 600)
        XCTAssertEqual(KeepAwakeDurationPreset.thirtyMinutes.duration.seconds, 1_800)
        XCTAssertEqual(KeepAwakeDurationPreset.oneHour.duration.seconds, 3_600)
        XCTAssertEqual(KeepAwakeDurationPreset.twoHours.duration.seconds, 7_200)
        XCTAssertEqual(KeepAwakeDurationPreset.fourHours.duration.seconds, 14_400)
        XCTAssertEqual(KeepAwakeDurationPreset.eightHours.duration.seconds, 28_800)
        XCTAssertEqual(KeepAwakeDurationPreset.twelveHours.duration.seconds, 43_200)
    }

    func testIndicatorStylesIncludeCupAndColoredVariants() {
        XCTAssertEqual(KeepAwakeIndicatorStyle.allCases.map(\.title), [
            "Normal",
            "Green Cup",
            "Blue Cup",
            "Green Icon",
            "Blue Icon"
        ])
    }

    func testDurationValidation() {
        XCTAssertTrue(KeepAwakeDuration.indefinitely.isValid)
        XCTAssertTrue(KeepAwakeDuration.seconds(0.5).isValid)
        XCTAssertFalse(KeepAwakeDuration.seconds(0).isValid)
        XCTAssertFalse(KeepAwakeDuration.seconds(-1).isValid)
        XCTAssertFalse(KeepAwakeDuration.seconds(.infinity).isValid)
        XCTAssertFalse(KeepAwakeDuration.seconds(.nan).isValid)
        XCTAssertFalse(
            KeepAwakeDuration.seconds(KeepAwakeDuration.maximumFiniteSeconds + 1).isValid
        )
    }

    func testParsesEveryURLCommand() throws {
        XCTAssertEqual(
            try parse("jostle:activate"),
            .activate(nil)
        )
        XCTAssertEqual(
            try parse("jostle:activate?minutes=10"),
            .activate(.seconds(600))
        )
        XCTAssertEqual(
            try parse("jostle:activate?hours=1&minutes=30"),
            .activate(.seconds(5_400))
        )
        XCTAssertEqual(
            try parse("jostle:activate?hours=1.5"),
            .activate(.seconds(5_400))
        )
        XCTAssertEqual(try parse("jostle:deactivate"), .deactivate)
        XCTAssertEqual(try parse("jostle:toggle"), .toggle(nil))
        XCTAssertEqual(
            try parse("jostle://toggle?minutes=2.5"),
            .toggle(.seconds(150))
        )
    }

    func testRejectsMalformedURLCommands() {
        assertParseError("https://example.com", equals: .invalidScheme)
        assertParseError("jostle:unknown", equals: .unsupportedCommand("unknown"))
        assertParseError("jostle:activate?seconds=5", equals: .unsupportedParameter("seconds"))
        assertParseError("jostle:activate?minutes=1&minutes=2", equals: .duplicateParameter("minutes"))
        assertParseError("jostle:activate?minutes=0", equals: .invalidDuration)
        assertParseError("jostle:activate?minutes=-1", equals: .invalidDuration)
        assertParseError("jostle:activate?hours=nan", equals: .invalidDuration)
        assertParseError("jostle:activate?hours=3000000", equals: .invalidDuration)
        assertParseError("jostle:activate?hours=1e308", equals: .invalidDuration)
        assertParseError("jostle:deactivate?minutes=1", equals: .unsupportedParameter("duration"))
    }

    private func parse(_ value: String) throws -> KeepAwakeCommand {
        try KeepAwakeURLCommandParser.parse(XCTUnwrap(URL(string: value)))
    }

    private func assertParseError(
        _ value: String,
        equals expected: KeepAwakeURLCommandError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try parse(value), file: file, line: line) { error in
            XCTAssertEqual(error as? KeepAwakeURLCommandError, expected, file: file, line: line)
        }
    }
}
