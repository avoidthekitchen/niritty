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
}
