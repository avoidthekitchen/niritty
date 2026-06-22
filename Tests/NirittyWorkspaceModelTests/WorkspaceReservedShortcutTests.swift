import AppKit
import XCTest
@testable import NirittyWorkspaceModel

final class WorkspaceReservedShortcutTests: XCTestCase {
    func testFocusShortcutsMapControlShiftArrows() {
        XCTAssertEqual(commandID(keyCode: 123, modifiers: [.control, .shift]), .focusLeft)
        XCTAssertEqual(commandID(keyCode: 124, modifiers: [.control, .shift]), .focusRight)
        XCTAssertEqual(commandID(keyCode: 126, modifiers: [.control, .shift]), .focusUp)
        XCTAssertEqual(commandID(keyCode: 125, modifiers: [.control, .shift]), .focusDown)
    }

    func testMovementShortcutsMapControlShiftCommandArrows() {
        XCTAssertEqual(commandID(keyCode: 123, modifiers: [.control, .shift, .command]), .moveColumnLeft)
        XCTAssertEqual(commandID(keyCode: 124, modifiers: [.control, .shift, .command]), .moveColumnRight)
        XCTAssertEqual(commandID(keyCode: 126, modifiers: [.control, .shift, .command]), .transferColumnUp)
        XCTAssertEqual(commandID(keyCode: 125, modifiers: [.control, .shift, .command]), .transferColumnDown)
    }

    func testShortcutOverlayMapsControlShiftSlash() {
        XCTAssertEqual(commandID(keyCode: 44, characters: "/", modifiers: [.control, .shift]), .showShortcutOverlay)
    }

    func testUnreservedKeyEventsPassThrough() {
        XCTAssertNil(commandID(keyCode: 123, modifiers: [.command]))
        XCTAssertNil(commandID(keyCode: 0, characters: "a", modifiers: [.control, .shift]))
    }

    private func commandID(
        keyCode: UInt16,
        characters: String = "",
        modifiers: NSEvent.ModifierFlags
    ) -> WorkspaceCommandID? {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!

        return WorkspaceReservedShortcut.commandID(for: event)
    }
}
