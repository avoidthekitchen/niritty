import AppKit
import GhosttyKit

struct TerminalMousePosition: Equatable {
    let x: Double
    let y: Double
}

enum TerminalMouseEventEncoder {
    static func ghosttyPosition(localPoint: NSPoint, bounds: NSRect) -> TerminalMousePosition {
        TerminalMousePosition(
            x: Double(localPoint.x),
            y: Double(bounds.height - localPoint.y)
        )
    }

    static func ghosttyButton(from event: NSEvent) -> ghostty_input_mouse_button_e {
        ghosttyButton(fromButtonNumber: event.buttonNumber)
    }

    static func ghosttyButton(fromButtonNumber buttonNumber: Int) -> ghostty_input_mouse_button_e {
        switch buttonNumber {
        case 0:
            GHOSTTY_MOUSE_LEFT
        case 1:
            GHOSTTY_MOUSE_RIGHT
        case 2:
            GHOSTTY_MOUSE_MIDDLE
        case 3:
            GHOSTTY_MOUSE_EIGHT
        case 4:
            GHOSTTY_MOUSE_NINE
        case 5:
            GHOSTTY_MOUSE_SIX
        case 6:
            GHOSTTY_MOUSE_SEVEN
        case 7:
            GHOSTTY_MOUSE_FOUR
        case 8:
            GHOSTTY_MOUSE_FIVE
        case 9:
            GHOSTTY_MOUSE_TEN
        case 10:
            GHOSTTY_MOUSE_ELEVEN
        default:
            GHOSTTY_MOUSE_UNKNOWN
        }
    }

    static func scrollX(from event: NSEvent) -> Double {
        scaledScrollDelta(event.scrollingDeltaX, isPrecise: event.hasPreciseScrollingDeltas)
    }

    static func scrollY(from event: NSEvent) -> Double {
        scaledScrollDelta(event.scrollingDeltaY, isPrecise: event.hasPreciseScrollingDeltas)
    }

    static func scrollMods(from flags: NSEvent.ModifierFlags) -> ghostty_input_scroll_mods_t {
        ghostty_input_scroll_mods_t(TerminalKeyEventEncoder.ghosttyMods(from: flags).rawValue)
    }

    private static func scaledScrollDelta(_ delta: Double, isPrecise: Bool) -> Double {
        isPrecise ? delta * 2 : delta
    }
}
