import AppKit
import GhosttyKit

enum TerminalKeyEventEncoder {
    static func ghosttyKeyEvent(from event: NSEvent, action: ghostty_input_action_e) -> ghostty_input_key_s {
        var keyEvent = ghostty_input_key_s()
        keyEvent.action = action
        keyEvent.mods = ghosttyMods(from: event.modifierFlags)
        keyEvent.consumed_mods = ghosttyMods(from: event.modifierFlags.subtracting([.control, .command]))
        keyEvent.keycode = UInt32(event.keyCode)
        keyEvent.unshifted_codepoint = unshiftedCodepoint(from: event)
        keyEvent.composing = false
        keyEvent.text = nil
        return keyEvent
    }

    static func text(for event: NSEvent) -> String? {
        guard event.type == .keyDown else { return nil }
        guard let text = event.characters, !text.isEmpty else {
            return nil
        }

        if text.count == 1,
           let scalar = text.unicodeScalars.first {
            if scalar.value < 0x20 || scalar.value == 0x7F {
                if event.keyCode == 51 {
                    return "\u{7F}"
                }

                let translated = event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
                guard let translatedScalar = translated?.utf8.first,
                      translatedScalar >= 0x20,
                      translatedScalar != 0x7F else {
                    return nil
                }
                return translated
            }

            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }

        return text
    }

    private static func ghosttyMods(from flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var rawValue: UInt32 = GHOSTTY_MODS_NONE.rawValue

        if flags.contains(.shift) {
            rawValue |= GHOSTTY_MODS_SHIFT.rawValue
        }
        if flags.contains(.control) {
            rawValue |= GHOSTTY_MODS_CTRL.rawValue
        }
        if flags.contains(.option) {
            rawValue |= GHOSTTY_MODS_ALT.rawValue
        }
        if flags.contains(.command) {
            rawValue |= GHOSTTY_MODS_SUPER.rawValue
        }
        if flags.contains(.capsLock) {
            rawValue |= GHOSTTY_MODS_CAPS.rawValue
        }

        return ghostty_input_mods_e(rawValue: rawValue)
    }

    private static func unshiftedCodepoint(from event: NSEvent) -> UInt32 {
        switch event.keyCode {
        case 36:
            return 0x0D
        case 48:
            return 0x09
        case 51:
            return 0x7F
        case 53:
            return 0x1B
        default:
            break
        }

        guard event.type == .keyDown || event.type == .keyUp else {
            return 0
        }
        guard let scalar = event.characters(byApplyingModifiers: [])?.unicodeScalars.first else {
            return 0
        }

        return scalar.value
    }
}
