import JostleCore
import XCTest
@testable import Jostle

final class ShortcutFormatterTests: XCTestCase {
    func testFormatsRecommendedShortcut() {
        let shortcut = GlobalShortcut(
            keyCode: 37,
            modifiers: [.command, .control]
        )

        XCTAssertEqual(ShortcutFormatter.string(for: shortcut), "⌃⌘L")
    }

    func testFormatsUnknownKeyWithoutLosingModifiers() {
        let shortcut = GlobalShortcut(
            keyCode: 999,
            modifiers: [.option, .shift]
        )

        XCTAssertEqual(ShortcutFormatter.string(for: shortcut), "⌥⇧Key 999")
    }
}
