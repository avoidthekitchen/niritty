import AppKit

public enum WorkspaceReservedShortcut {
    private static let workspaceModifierFlags: NSEvent.ModifierFlags = [.control, .shift]
    private static let movementModifierFlags: NSEvent.ModifierFlags = [.control, .shift, .command]
    private static let comparedModifierFlags: NSEvent.ModifierFlags = [.control, .shift, .command, .option]

    public static func commandID(for event: NSEvent) -> WorkspaceCommandID? {
        guard event.type == .keyDown else {
            return nil
        }

        let modifiers = event.modifierFlags.intersection(comparedModifierFlags)

        if modifiers == workspaceModifierFlags {
            switch event.keyCode {
            case 123:
                return .focusLeft
            case 124:
                return .focusRight
            case 126:
                return .focusUp
            case 125:
                return .focusDown
            default:
                if event.charactersIgnoringModifiers == "/" {
                    return .showShortcutOverlay
                }
            }
        }

        if modifiers == movementModifierFlags {
            switch event.keyCode {
            case 123:
                return .moveColumnLeft
            case 124:
                return .moveColumnRight
            case 126:
                return .transferColumnUp
            case 125:
                return .transferColumnDown
            default:
                return nil
            }
        }

        return nil
    }
}
