import Foundation

public struct WorkspaceStackSnapshot: Codable, Equatable, Sendable {
    public let workspaces: [WorkspaceSnapshot]
    public let focusedWorkspaceID: Workspace.ID?

    public init(stack: WorkspaceStack) {
        workspaces = stack.workspaces
            .filter { !$0.isEmptyWorkspace }
            .map(WorkspaceSnapshot.init(workspace:))
        focusedWorkspaceID = workspaces.contains { $0.id == stack.focusedWorkspaceID }
            ? stack.focusedWorkspaceID
            : workspaces.first?.id
    }
}

public struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    public let id: Workspace.ID
    public let columns: [ColumnSnapshot]
    public let focusedWindowID: WorkspaceWindow.ID?
    public let horizontalScrollPosition: Double
    public let workspaceRoot: URL

    init(workspace: Workspace) {
        id = workspace.id
        columns = workspace.columns.map(ColumnSnapshot.init(column:))
        focusedWindowID = workspace.focusedWindowID
        horizontalScrollPosition = workspace.horizontalScrollPosition
        workspaceRoot = workspace.workspaceRoot
    }
}

public struct ColumnSnapshot: Codable, Equatable, Sendable {
    public let id: Column.ID
    public let widthMode: ColumnWidthMode
    public let windows: [WorkspaceWindowSnapshot]

    init(column: Column) {
        id = column.id
        widthMode = column.widthMode
        windows = column.windows.map(WorkspaceWindowSnapshot.init(window:))
    }
}

public struct WorkspaceWindowSnapshot: Codable, Equatable, Sendable {
    public let id: WorkspaceWindow.ID
    public let kind: WindowKind
    public let restoreMetadata: WindowRestoreMetadata

    init(window: WorkspaceWindow) {
        id = window.id
        kind = window.kind
        restoreMetadata = window.restoreMetadata
    }
}

extension WorkspaceStack {
    public static func restore(
        from snapshot: WorkspaceStackSnapshot,
        defaultWorkspaceRoot: URL
    ) -> WorkspaceStack {
        var workspaces = snapshot.workspaces.map { workspaceSnapshot in
            Workspace(
                id: workspaceSnapshot.id,
                columns: workspaceSnapshot.columns.map { columnSnapshot in
                    Column(
                        id: columnSnapshot.id,
                        widthMode: columnSnapshot.widthMode,
                        windows: columnSnapshot.windows.map { windowSnapshot in
                            WorkspaceWindow(
                                id: windowSnapshot.id,
                                kind: windowSnapshot.kind,
                                restoreMetadata: windowSnapshot.restoreMetadata.restoredFreshProcessMetadata(for: windowSnapshot.kind)
                            )
                        }
                    )
                },
                focusedWindowID: workspaceSnapshot.focusedWindowID,
                horizontalScrollPosition: workspaceSnapshot.horizontalScrollPosition,
                workspaceRoot: workspaceSnapshot.workspaceRoot
            )
        }

        let focusedWorkspaceID = snapshot.focusedWorkspaceID
            .flatMap { focusedID in workspaces.contains(where: { $0.id == focusedID }) ? focusedID : nil }
            ?? workspaces.first?.id

        let bottomWorkspaceRoot = workspaces.last?.workspaceRoot ?? defaultWorkspaceRoot
        workspaces.append(.empty(workspaceRoot: bottomWorkspaceRoot))

        guard let focusedWorkspaceID else {
            return .initial(workspaceRoot: defaultWorkspaceRoot)
        }

        return WorkspaceStack(
            workspaces: workspaces,
            focusedWorkspaceID: focusedWorkspaceID
        )
    }
}

private extension WindowRestoreMetadata {
    func restoredFreshProcessMetadata(for kind: WindowKind) -> WindowRestoreMetadata {
        guard kind == .terminal else {
            return self
        }

        var metadata = self
        metadata.isTerminalExited = false
        return metadata
    }
}
