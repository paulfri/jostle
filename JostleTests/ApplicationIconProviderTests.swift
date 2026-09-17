import AppKit
import XCTest
@testable import Jostle

final class ApplicationIconProviderTests: XCTestCase {
    func testInstalledApplicationIconPreservesRetinaRepresentation() throws {
        let icon = try XCTUnwrap(
            ApplicationIconProvider.icon(
                applicationKey: "com.apple.finder",
                displayName: "Finder"
            )
        )

        XCTAssertEqual(icon.size, NSSize(width: 32, height: 32))
        XCTAssertTrue(
            icon.representations.contains {
                $0.pixelsWide >= 64 && $0.pixelsHigh >= 64
            }
        )
    }
}
