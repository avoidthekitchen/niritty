import AppKit
import GhosttyKit
import XCTest
@testable import NirittyGhosttyTerminal

final class TerminalKeyEventEncoderTests: XCTestCase {
    func testReturnAndDeleteAreSentAsStructuredKeysNotText() {
        let returnEvent = keyEvent(keyCode: 36, characters: "\r")
        let deleteEvent = keyEvent(keyCode: 51, characters: "\u{7F}")

        XCTAssertNil(TerminalKeyEventEncoder.text(for: returnEvent))
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(from: returnEvent, action: GHOSTTY_ACTION_PRESS).keycode,
            36
        )
        XCTAssertNil(TerminalKeyEventEncoder.text(for: deleteEvent))
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(from: deleteEvent, action: GHOSTTY_ACTION_PRESS).keycode,
            51
        )
    }

    func testPrintableCharactersCarryTextForGhosttyKeyEvent() {
        let event = keyEvent(keyCode: 0, characters: "a")

        XCTAssertEqual(TerminalKeyEventEncoder.text(for: event), "a")
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(from: event, action: GHOSTTY_ACTION_PRESS).unshifted_codepoint,
            Unicode.Scalar("a").value
        )
    }

    func testControlModifiedPrintableTextCarriesModifierState() {
        let event = keyEvent(keyCode: 0, characters: "\u{1}", modifiers: .control)
        let keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: event, action: GHOSTTY_ACTION_PRESS)

        XCTAssertEqual(TerminalKeyEventEncoder.text(for: event), "a")
        XCTAssertTrue(keyEvent.mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0)
    }

    private func keyEvent(
        keyCode: UInt16,
        characters: String,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
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
    }
}
