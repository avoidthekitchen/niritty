import GhosttyKit
import XCTest
@testable import NirittyGhosttyTerminal

final class TerminalClipboardBridgeTests: XCTestCase {
    func testStandardClipboardReadRequiresStringAndSurface() {
        XCTAssertFalse(TerminalClipboardBridge.canCompleteStandardRead(
            clipboard: GHOSTTY_CLIPBOARD_STANDARD,
            string: nil,
            hasSurface: true
        ))
        XCTAssertFalse(TerminalClipboardBridge.canCompleteStandardRead(
            clipboard: GHOSTTY_CLIPBOARD_STANDARD,
            string: "pwd",
            hasSurface: false
        ))
        XCTAssertFalse(TerminalClipboardBridge.canCompleteStandardRead(
            clipboard: GHOSTTY_CLIPBOARD_SELECTION,
            string: "pwd",
            hasSurface: true
        ))
        XCTAssertTrue(TerminalClipboardBridge.canCompleteStandardRead(
            clipboard: GHOSTTY_CLIPBOARD_STANDARD,
            string: "pwd",
            hasSurface: true
        ))
    }

    func testCompleteStandardReadPassesConfirmationPolicy() {
        var completions: [(string: String, confirmed: Bool)] = []
        let fakeSurface = UnsafeMutableRawPointer(bitPattern: 1)!

        XCTAssertTrue(TerminalClipboardBridge.completeStandardRead(
            clipboard: GHOSTTY_CLIPBOARD_STANDARD,
            string: "printf pasted",
            surface: fakeSurface,
            state: nil,
            confirmed: true,
            complete: { _, string, _, confirmed in
                completions.append((string, confirmed))
            }
        ))

        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions[0].string, "printf pasted")
        XCTAssertTrue(completions[0].confirmed)
    }
}
