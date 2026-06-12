import AppKit
import GhosttyKit

enum TerminalClipboardBridge {
    static func completeStandardRead(
        clipboard: ghostty_clipboard_e,
        string: String?,
        surface: ghostty_surface_t?,
        state: UnsafeMutableRawPointer?,
        complete: (ghostty_surface_t, String, UnsafeMutableRawPointer?) -> Void = completeClipboardRequest
    ) -> Bool {
        guard canCompleteStandardRead(
            clipboard: clipboard,
            string: string,
            hasSurface: surface != nil
        ),
            let string,
            let surface else {
            return false
        }

        complete(surface, string, state)
        return true
    }

    static func canCompleteStandardRead(
        clipboard: ghostty_clipboard_e,
        string: String?,
        hasSurface: Bool
    ) -> Bool {
        clipboard == GHOSTTY_CLIPBOARD_STANDARD && string != nil && hasSurface
    }

    private static func completeClipboardRequest(
        surface: ghostty_surface_t,
        string: String,
        state: UnsafeMutableRawPointer?
    ) {
        string.withCString { pointer in
            ghostty_surface_complete_clipboard_request(surface, pointer, state, false)
        }
    }
}
