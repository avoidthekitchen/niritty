import Foundation
import NirittyWorkspaceModel
import OSLog

private enum NirittyTelemetry {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.niritty.Niritty"

    static let workspace = Logger(subsystem: subsystem, category: "Workspace")
}

private struct WorkspaceFocusTelemetryState {
    let focusedWorkspaceIndex: Int?
    let focusedWorkspaceID: String
    let focusedColumnIndex: Int?
    let workspaceColumnCounts: [Int]

    init(workspaceStack: WorkspaceStack) {
        focusedWorkspaceIndex = workspaceStack.workspaces.firstIndex { workspace in
            workspace.id == workspaceStack.focusedWorkspaceID
        }
        focusedWorkspaceID = workspaceStack.focusedWorkspaceID.uuidString
        workspaceColumnCounts = workspaceStack.workspaces.map(\.columns.count)

        if let focusedWorkspaceIndex {
            focusedColumnIndex = workspaceStack.workspaces[focusedWorkspaceIndex].focusedColumnIndex
        } else {
            focusedColumnIndex = nil
        }
    }

    var description: String {
        let workspaceLabel = focusedWorkspaceIndex.map { "w\($0 + 1)" } ?? "missing"
        let columnLabel = focusedColumnIndex.map { "c\($0 + 1)" } ?? "no-column"
        return "\(workspaceLabel)/\(columnLabel) id=\(focusedWorkspaceID) columns=\(workspaceColumnCounts)"
    }
}

func executeWorkspaceCommand(
    _ commandID: WorkspaceCommandID,
    workspaceStack: inout WorkspaceStack,
    isShortcutOverlayPresented: inout Bool,
    visibleColumnCount: Int
) {
    let before = WorkspaceFocusTelemetryState(workspaceStack: workspaceStack)

    switch commandID {
    case .focusLeft:
        workspaceStack.moveFocus(.left, visibleColumnCount: visibleColumnCount)
    case .focusRight:
        workspaceStack.moveFocus(.right, visibleColumnCount: visibleColumnCount)
    case .focusUp:
        workspaceStack.moveFocus(.up, visibleColumnCount: visibleColumnCount)
    case .focusDown:
        workspaceStack.moveFocus(.down, visibleColumnCount: visibleColumnCount)
    case .moveColumnLeft:
        workspaceStack.moveFocusedColumn(.left, visibleColumnCount: visibleColumnCount)
    case .moveColumnRight:
        workspaceStack.moveFocusedColumn(.right, visibleColumnCount: visibleColumnCount)
    case .transferColumnUp:
        workspaceStack.moveFocusedColumn(.up, visibleColumnCount: visibleColumnCount)
    case .transferColumnDown:
        workspaceStack.moveFocusedColumn(.down, visibleColumnCount: visibleColumnCount)
    case .showShortcutOverlay:
        isShortcutOverlayPresented = true
    }

    let after = WorkspaceFocusTelemetryState(workspaceStack: workspaceStack)
    NirittyTelemetry.workspace.info(
        "Workspace command \(commandID.telemetryName, privacy: .public): before=\(before.description, privacy: .public) after=\(after.description, privacy: .public)"
    )
}
