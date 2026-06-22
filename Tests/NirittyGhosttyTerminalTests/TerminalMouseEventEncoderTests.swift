import AppKit
import GhosttyKit
import XCTest
@testable import NirittyGhosttyTerminal

final class TerminalMouseEventEncoderTests: XCTestCase {
    func testPositionUsesGhosttyTopLeftYCoordinate() {
        let position = TerminalMouseEventEncoder.ghosttyPosition(
            localPoint: NSPoint(x: 12, y: 80),
            bounds: NSRect(x: 0, y: 0, width: 200, height: 100)
        )

        XCTAssertEqual(position, TerminalMousePosition(x: 12, y: 20))
    }

    func testMouseButtonsMatchGhosttyAppKitMapping() {
        XCTAssertEqual(TerminalMouseEventEncoder.ghosttyButton(fromButtonNumber: 0), GHOSTTY_MOUSE_LEFT)
        XCTAssertEqual(TerminalMouseEventEncoder.ghosttyButton(fromButtonNumber: 1), GHOSTTY_MOUSE_RIGHT)
        XCTAssertEqual(TerminalMouseEventEncoder.ghosttyButton(fromButtonNumber: 2), GHOSTTY_MOUSE_MIDDLE)
        XCTAssertEqual(TerminalMouseEventEncoder.ghosttyButton(fromButtonNumber: 3), GHOSTTY_MOUSE_EIGHT)
        XCTAssertEqual(TerminalMouseEventEncoder.ghosttyButton(fromButtonNumber: 4), GHOSTTY_MOUSE_NINE)
        XCTAssertEqual(TerminalMouseEventEncoder.ghosttyButton(fromButtonNumber: 99), GHOSTTY_MOUSE_UNKNOWN)
    }

    func testScrollModsReuseGhosttyKeyboardModifierEncoding() {
        let mods = TerminalMouseEventEncoder.scrollMods(from: [.control, .shift])

        XCTAssertTrue(mods & ghostty_input_scroll_mods_t(GHOSTTY_MODS_CTRL.rawValue) != 0)
        XCTAssertTrue(mods & ghostty_input_scroll_mods_t(GHOSTTY_MODS_SHIFT.rawValue) != 0)
    }
}
