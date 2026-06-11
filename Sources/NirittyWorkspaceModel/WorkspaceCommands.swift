import Foundation

public struct WorkspaceCommandRegistry: Equatable, Sendable {
    public let commands: [WorkspaceCommand]

    public static let v1 = WorkspaceCommandRegistry(commands: [
        WorkspaceCommand(id: .focusLeft, title: "Focus Left", shortcut: .controlOption("Left")),
        WorkspaceCommand(id: .focusRight, title: "Focus Right", shortcut: .controlOption("Right")),
        WorkspaceCommand(id: .focusUp, title: "Focus Up", shortcut: .controlOption("Up")),
        WorkspaceCommand(id: .focusDown, title: "Focus Down", shortcut: .controlOption("Down")),
        WorkspaceCommand(id: .moveColumnLeft, title: "Move Column Left", shortcut: .controlOptionCommand("Left")),
        WorkspaceCommand(id: .moveColumnRight, title: "Move Column Right", shortcut: .controlOptionCommand("Right")),
        WorkspaceCommand(id: .transferColumnUp, title: "Transfer Column Up", shortcut: .controlOptionCommand("Up")),
        WorkspaceCommand(id: .transferColumnDown, title: "Transfer Column Down", shortcut: .controlOptionCommand("Down")),
        WorkspaceCommand(id: .showShortcutOverlay, title: "Shortcut Overlay", shortcut: .controlOptionCommand("/")),
    ])
}

public struct WorkspaceCommand: Identifiable, Equatable, Sendable {
    public let id: WorkspaceCommandID
    public let title: String
    public let shortcut: WorkspaceShortcut
}

public enum WorkspaceCommandID: String, Equatable, Sendable {
    case focusLeft
    case focusRight
    case focusUp
    case focusDown
    case moveColumnLeft
    case moveColumnRight
    case transferColumnUp
    case transferColumnDown
    case showShortcutOverlay
}

public struct WorkspaceShortcut: Equatable, Sendable {
    public let modifiers: [WorkspaceShortcutModifier]
    public let key: String

    public var displayText: String {
        (modifiers.map(\.displayText) + [key]).joined(separator: "+")
    }

    public static func controlOption(_ key: String) -> WorkspaceShortcut {
        WorkspaceShortcut(modifiers: [.control, .option], key: key)
    }

    public static func controlOptionCommand(_ key: String) -> WorkspaceShortcut {
        WorkspaceShortcut(modifiers: [.control, .option, .command], key: key)
    }
}

public enum WorkspaceShortcutModifier: String, Equatable, Sendable {
    case control
    case option
    case command

    public var displayText: String {
        switch self {
        case .control:
            "Ctrl"
        case .option:
            "Option"
        case .command:
            "Command"
        }
    }
}

public struct ShortcutOverlayModel: Equatable, Sendable {
    public let rows: [ShortcutOverlayRow]

    public init(registry: WorkspaceCommandRegistry) {
        rows = registry.commands.map { command in
            ShortcutOverlayRow(
                commandTitle: command.title,
                shortcutText: command.shortcut.displayText
            )
        }
    }
}

public struct ShortcutOverlayRow: Equatable, Sendable {
    public let commandTitle: String
    public let shortcutText: String
}
