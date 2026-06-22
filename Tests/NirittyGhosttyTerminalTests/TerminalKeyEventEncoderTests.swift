import AppKit
import GhosttyKit
import XCTest
@testable import NirittyGhosttyTerminal

final class TerminalKeyEventEncoderTests: XCTestCase {
    func testReturnIsSentAsStructuredKeyNotText() {
        let returnEvent = keyEvent(keyCode: 36, characters: "\r")

        XCTAssertNil(TerminalKeyEventEncoder.text(for: returnEvent))
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(from: returnEvent, action: GHOSTTY_ACTION_PRESS).keycode,
            36
        )
    }

    func testDeleteUsesStructuredKeyWithoutControlText() {
        let deleteEvent = keyEvent(keyCode: 51, characters: "\u{7F}")
        let keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: deleteEvent, action: GHOSTTY_ACTION_PRESS)

        XCTAssertNil(TerminalKeyEventEncoder.text(for: deleteEvent))
        XCTAssertEqual(keyEvent.keycode, 51)
        XCTAssertEqual(keyEvent.unshifted_codepoint, 0x08)
    }

    func testModifiedDeleteUsesStructuredKeyWithoutControlText() {
        let deleteEvent = keyEvent(keyCode: 51, characters: "\u{7F}", modifiers: .option)
        let keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: deleteEvent, action: GHOSTTY_ACTION_PRESS)

        XCTAssertNil(TerminalKeyEventEncoder.text(for: deleteEvent))
        XCTAssertEqual(keyEvent.keycode, 51)
        XCTAssertEqual(keyEvent.unshifted_codepoint, 0x08)
        XCTAssertTrue(keyEvent.mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0)
    }

    func testForwardDeleteUsesStructuredKeyWithoutPrivateUseText() {
        let forwardDeleteEvent = keyEvent(keyCode: 117, characters: "\u{F728}")
        let keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: forwardDeleteEvent, action: GHOSTTY_ACTION_PRESS)

        XCTAssertNil(TerminalKeyEventEncoder.text(for: forwardDeleteEvent))
        XCTAssertEqual(keyEvent.keycode, 117)
    }

    func testSyntheticBackspaceEventUsesStructuredKeyWithoutControlText() throws {
        let event = try XCTUnwrap(TerminalKeyEventEncoder.syntheticKeyDown(
            keyCode: 51,
            characters: "\u{7F}",
            modifiers: [],
            windowNumber: 7
        ))
        let keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: event, action: GHOSTTY_ACTION_PRESS)

        XCTAssertEqual(event.type, .keyDown)
        XCTAssertNil(TerminalKeyEventEncoder.text(for: event))
        XCTAssertEqual(keyEvent.keycode, 51)
        XCTAssertEqual(keyEvent.unshifted_codepoint, 0x08)
    }

    func testSyntheticForwardDeleteEventMatchesGhosttyForwardDeleteShape() throws {
        let event = try XCTUnwrap(TerminalKeyEventEncoder.syntheticKeyDown(
            keyCode: 117,
            characters: "\u{F728}",
            modifiers: [],
            windowNumber: 7
        ))
        let keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: event, action: GHOSTTY_ACTION_PRESS)

        XCTAssertEqual(event.type, .keyDown)
        XCTAssertNil(TerminalKeyEventEncoder.text(for: event))
        XCTAssertEqual(keyEvent.keycode, 117)
    }

    func testSpecialKeysUseDynamicUnshiftedCodepoints() {
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(
                from: keyEvent(keyCode: 36, characters: "\r"),
                action: GHOSTTY_ACTION_PRESS
            ).unshifted_codepoint,
            0x0D
        )
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(
                from: keyEvent(keyCode: 48, characters: "\t"),
                action: GHOSTTY_ACTION_PRESS
            ).unshifted_codepoint,
            0x09
        )
        XCTAssertEqual(
            TerminalKeyEventEncoder.ghosttyKeyEvent(
                from: keyEvent(keyCode: 53, characters: "\u{1B}"),
                action: GHOSTTY_ACTION_PRESS
            ).unshifted_codepoint,
            0x1B
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
