import AppKit
import GhosttyKit

enum TerminalClipboardBridge {
    static func completeStandardRead(
        clipboard: ghostty_clipboard_e,
        string: String?,
        surface: ghostty_surface_t?,
        state: UnsafeMutableRawPointer?,
        confirmed: Bool = false,
        complete: (ghostty_surface_t, String, UnsafeMutableRawPointer?, Bool) -> Void = completeClipboardRequest
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

        complete(surface, string, state, confirmed)
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
        state: UnsafeMutableRawPointer?,
        confirmed: Bool
    ) {
        string.withCString { pointer in
            ghostty_surface_complete_clipboard_request(surface, pointer, state, confirmed)
        }
    }
}
