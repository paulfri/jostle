import AppKit
import XCTest
@testable import Jostle

final class AppBrandTests: XCTestCase {
    func testBuildProfileBrandMatchesApplicationIdentity() throws {
        let color = try XCTUnwrap(AppBrand.accentColor.usingColorSpace(.sRGB))

        if AppBrand.applicationName == "Jostle Development" {
            XCTAssertEqual(Bundle.main.bundleIdentifier, "fm.pau.jostle.development")
            XCTAssertEqual(color.redComponent, 93.0 / 255.0, accuracy: 0.001)
            XCTAssertEqual(color.greenComponent, 155.0 / 255.0, accuracy: 0.001)
            XCTAssertEqual(color.blueComponent, 245.0 / 255.0, accuracy: 0.001)
        } else {
            XCTAssertEqual(AppBrand.applicationName, "Jostle")
            XCTAssertEqual(Bundle.main.bundleIdentifier, "fm.pau.jostle")
            XCTAssertEqual(color.redComponent, 245.0 / 255.0, accuracy: 0.001)
            XCTAssertEqual(color.greenComponent, 183.0 / 255.0, accuracy: 0.001)
            XCTAssertEqual(color.blueComponent, 93.0 / 255.0, accuracy: 0.001)
        }
    }

    func testSparkleConfigurationIsEmbeddedInApplicationBundle() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://github.com/paulfri/jostle/releases/latest/download/appcast.xml"
        )
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            "ge9/YT9aFJmz+JgpPUb5TQKC+zJnm6yPwN2vUnloM9Q="
        )
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool,
            false
        )
    }
}
