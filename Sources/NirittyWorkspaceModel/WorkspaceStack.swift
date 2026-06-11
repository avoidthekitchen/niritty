import Foundation

public struct WorkspaceStack: Equatable, Sendable {
    public var workspaces: [Workspace]
    public var focusedWorkspaceID: Workspace.ID

    public var workspaceRailMarkers: [WorkspaceRailMarker] {
        workspaces.map { workspace in
            WorkspaceRailMarker(
                workspaceID: workspace.id,
                isActive: workspace.id == focusedWorkspaceID,
                isOccupied: !workspace.isEmptyWorkspace
            )
        }
    }

    public static func initial(workspaceRoot: URL) -> WorkspaceStack {
        let emptyWorkspace = Workspace.empty(workspaceRoot: workspaceRoot)
        return WorkspaceStack(
            workspaces: [emptyWorkspace],
            focusedWorkspaceID: emptyWorkspace.id
        )
    }

    public mutating func createWindow(kind: WindowKind) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == focusedWorkspaceID }) else {
            return
        }

        let window = WorkspaceWindow(id: UUID(), kind: kind, restoreMetadata: .initial(for: kind))
        insertWindow(window, in: workspaceIndex)
    }

    public mutating func createTerminalWindow() {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == focusedWorkspaceID }) else {
            return
        }

        let window = WorkspaceWindow(
            id: UUID(),
            kind: .terminal,
            restoreMetadata: WindowRestoreMetadata(
                browserURL: nil,
                terminalCurrentDirectory: terminalLaunchDirectory(in: workspaceIndex),
                isTerminalExited: false
            )
        )
        insertWindow(window, in: workspaceIndex)
    }

    public mutating func updateTerminalCurrentDirectory(_ directory: URL, for windowID: WorkspaceWindow.ID) {
        guard let location = windowLocation(for: windowID),
              workspaces[location.workspaceIndex].columns[location.columnIndex].windows[location.windowIndex].kind == .terminal else {
            return
        }

        workspaces[location.workspaceIndex].columns[location.columnIndex].windows[location.windowIndex].restoreMetadata.terminalCurrentDirectory = directory
    }

    public mutating func markTerminalExited(windowID: WorkspaceWindow.ID) {
        updateTerminalExitedState(true, for: windowID)
    }

    public mutating func restartTerminal(windowID: WorkspaceWindow.ID) {
        updateTerminalExitedState(false, for: windowID)
    }

    private mutating func updateTerminalExitedState(_ isExited: Bool, for windowID: WorkspaceWindow.ID) {
        guard let location = windowLocation(for: windowID),
              workspaces[location.workspaceIndex].columns[location.columnIndex].windows[location.windowIndex].kind == .terminal else {
            return
        }

        workspaces[location.workspaceIndex].columns[location.columnIndex].windows[location.windowIndex].restoreMetadata.isTerminalExited = isExited
    }

    private mutating func insertWindow(_ window: WorkspaceWindow, in workspaceIndex: Int) {
        let column = Column(id: UUID(), widthMode: .half, windows: [window])
        let insertionIndex = workspaces[workspaceIndex].focusedColumnIndex.map { $0 + 1 }
            ?? workspaces[workspaceIndex].columns.endIndex
        workspaces[workspaceIndex].columns.insert(column, at: insertionIndex)
        workspaces[workspaceIndex].focusedWindowID = window.id

        maintainBottomEmptyWorkspace()
    }

    public mutating func focusWorkspace(id: Workspace.ID) {
        guard workspaces.contains(where: { $0.id == id }) else {
            return
        }

        focusedWorkspaceID = id
        maintainBottomEmptyWorkspace()
    }

    public mutating func focusWindow(id: WorkspaceWindow.ID) {
        guard let workspaceIndex = workspaces.firstIndex(where: { workspace in
            workspace.columns.contains { column in
                column.windows.contains { $0.id == id }
            }
        }) else {
            return
        }

        focusedWorkspaceID = workspaces[workspaceIndex].id
        workspaces[workspaceIndex].focusedWindowID = id
        maintainBottomEmptyWorkspace()
    }

    public mutating func closeWindow(id: WorkspaceWindow.ID) {
        guard let workspaceIndex = workspaces.firstIndex(where: { workspace in
            workspace.columns.contains { column in
                column.windows.contains { $0.id == id }
            }
        }) else {
            return
        }

        guard let columnIndex = workspaces[workspaceIndex].columns.firstIndex(where: { column in
            column.windows.contains { $0.id == id }
        }) else {
            return
        }

        workspaces[workspaceIndex].columns[columnIndex].windows.removeAll { $0.id == id }

        if workspaces[workspaceIndex].columns[columnIndex].windows.isEmpty {
            workspaces[workspaceIndex].columns.remove(at: columnIndex)
        }

        if workspaces[workspaceIndex].focusedWindowID == id {
            let nextFocusedColumnIndex = min(columnIndex, workspaces[workspaceIndex].columns.count - 1)
            workspaces[workspaceIndex].focusedWindowID = if nextFocusedColumnIndex >= 0 {
                workspaces[workspaceIndex].columns[nextFocusedColumnIndex].windows.first?.id
            } else {
                nil
            }
        }

        maintainBottomEmptyWorkspace()
    }

    public mutating func commitBrowserURL(_ url: URL, for windowID: WorkspaceWindow.ID) {
        guard let location = windowLocation(for: windowID),
              workspaces[location.workspaceIndex].columns[location.columnIndex].windows[location.windowIndex].kind == .browser else {
            return
        }

        workspaces[location.workspaceIndex].columns[location.columnIndex].windows[location.windowIndex].restoreMetadata.browserURL = url
    }

    public mutating func setHorizontalScrollPosition(_ position: Double, for workspaceID: Workspace.ID) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            return
        }

        workspaces[workspaceIndex].horizontalScrollPosition = position
    }

    public mutating func moveFocus(_ direction: FocusDirection, visibleColumnCount: Int) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == focusedWorkspaceID }) else {
            return
        }

        switch direction {
        case .left:
            moveFocusHorizontally(in: workspaceIndex, offset: -1, visibleColumnCount: visibleColumnCount)
        case .right:
            moveFocusHorizontally(in: workspaceIndex, offset: 1, visibleColumnCount: visibleColumnCount)
        case .up:
            moveFocusVertically(from: workspaceIndex, offset: -1, visibleColumnCount: visibleColumnCount)
        case .down:
            moveFocusVertically(from: workspaceIndex, offset: 1, visibleColumnCount: visibleColumnCount)
        }
    }

    public mutating func rotateFocusedColumnWidth() {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == focusedWorkspaceID }),
              let focusedColumnIndex = workspaces[workspaceIndex].focusedColumnIndex else {
            return
        }

        workspaces[workspaceIndex].columns[focusedColumnIndex].widthMode.rotateToNextLargerMode()
    }

    public mutating func moveFocusedColumn(_ direction: FocusDirection, visibleColumnCount: Int) {
        guard let workspaceIndex = workspaces.firstIndex(where: { $0.id == focusedWorkspaceID }),
              let focusedColumnIndex = workspaces[workspaceIndex].focusedColumnIndex else {
            return
        }

        switch direction {
        case .left:
            moveColumn(in: workspaceIndex, from: focusedColumnIndex, to: focusedColumnIndex - 1, visibleColumnCount: visibleColumnCount)
        case .right:
            moveColumn(in: workspaceIndex, from: focusedColumnIndex, to: focusedColumnIndex + 1, visibleColumnCount: visibleColumnCount)
        case .up:
            transferColumn(from: workspaceIndex, columnIndex: focusedColumnIndex, workspaceOffset: -1, visibleColumnCount: visibleColumnCount)
        case .down:
            transferColumn(from: workspaceIndex, columnIndex: focusedColumnIndex, workspaceOffset: 1, visibleColumnCount: visibleColumnCount)
        }
    }

    private func windowLocation(for windowID: WorkspaceWindow.ID) -> (
        workspaceIndex: Int,
        columnIndex: Int,
        windowIndex: Int
    )? {
        for workspaceIndex in workspaces.indices {
            for columnIndex in workspaces[workspaceIndex].columns.indices {
                if let windowIndex = workspaces[workspaceIndex].columns[columnIndex].windows.firstIndex(where: { $0.id == windowID }) {
                    return (workspaceIndex, columnIndex, windowIndex)
                }
            }
        }

        return nil
    }

    private func terminalLaunchDirectory(in workspaceIndex: Int) -> URL {
        if let focusedColumnIndex = workspaces[workspaceIndex].focusedColumnIndex,
           let focusedWindow = workspaces[workspaceIndex].columns[focusedColumnIndex].windows.first,
           focusedWindow.kind == .terminal,
           let terminalCurrentDirectory = focusedWindow.restoreMetadata.terminalCurrentDirectory {
            return terminalCurrentDirectory
        }

        return workspaces[workspaceIndex].workspaceRoot
    }

    private mutating func moveFocusHorizontally(
        in workspaceIndex: Int,
        offset: Int,
        visibleColumnCount: Int
    ) {
        guard let focusedColumnIndex = workspaces[workspaceIndex].focusedColumnIndex else {
            return
        }

        let lastColumnIndex = workspaces[workspaceIndex].columns.index(before: workspaces[workspaceIndex].columns.endIndex)
        let targetColumnIndex = min(
            max(focusedColumnIndex + offset, workspaces[workspaceIndex].columns.startIndex),
            lastColumnIndex
        )
        guard let targetWindowID = workspaces[workspaceIndex].columns[targetColumnIndex].windows.first?.id else {
            return
        }

        workspaces[workspaceIndex].focusedWindowID = targetWindowID
        revealColumn(at: targetColumnIndex, in: workspaceIndex, visibleColumnCount: visibleColumnCount)
    }

    private mutating func moveColumn(
        in workspaceIndex: Int,
        from sourceColumnIndex: Int,
        to proposedTargetColumnIndex: Int,
        visibleColumnCount: Int
    ) {
        guard workspaces[workspaceIndex].columns.indices.contains(sourceColumnIndex) else {
            return
        }

        let targetColumnIndex = min(
            max(proposedTargetColumnIndex, workspaces[workspaceIndex].columns.startIndex),
            workspaces[workspaceIndex].columns.index(before: workspaces[workspaceIndex].columns.endIndex)
        )
        guard sourceColumnIndex != targetColumnIndex else {
            return
        }

        let column = workspaces[workspaceIndex].columns.remove(at: sourceColumnIndex)
        workspaces[workspaceIndex].columns.insert(column, at: targetColumnIndex)
        workspaces[workspaceIndex].focusedWindowID = column.windows.first?.id
        revealColumn(at: targetColumnIndex, in: workspaceIndex, visibleColumnCount: visibleColumnCount)
    }

    private mutating func transferColumn(
        from sourceWorkspaceIndex: Int,
        columnIndex: Int,
        workspaceOffset: Int,
        visibleColumnCount: Int
    ) {
        let targetWorkspaceIndex = sourceWorkspaceIndex + workspaceOffset
        guard workspaces.indices.contains(sourceWorkspaceIndex),
              workspaces.indices.contains(targetWorkspaceIndex),
              workspaces[sourceWorkspaceIndex].columns.indices.contains(columnIndex) else {
            return
        }

        let column = workspaces[sourceWorkspaceIndex].columns.remove(at: columnIndex)
        let targetColumnIndex = min(columnIndex, workspaces[targetWorkspaceIndex].columns.endIndex)
        workspaces[targetWorkspaceIndex].columns.insert(column, at: targetColumnIndex)

        workspaces[sourceWorkspaceIndex].focusedWindowID = {
            guard !workspaces[sourceWorkspaceIndex].columns.isEmpty else {
                return nil
            }

            let nextFocusedColumnIndex = min(columnIndex, workspaces[sourceWorkspaceIndex].columns.count - 1)
            return workspaces[sourceWorkspaceIndex].columns[nextFocusedColumnIndex].windows.first?.id
        }()

        focusedWorkspaceID = workspaces[targetWorkspaceIndex].id
        workspaces[targetWorkspaceIndex].focusedWindowID = column.windows.first?.id
        revealColumn(at: targetColumnIndex, in: targetWorkspaceIndex, visibleColumnCount: visibleColumnCount)
        maintainBottomEmptyWorkspace()
    }

    private mutating func moveFocusVertically(
        from workspaceIndex: Int,
        offset: Int,
        visibleColumnCount: Int
    ) {
        let targetWorkspaceIndex = workspaceIndex + offset
        guard workspaces.indices.contains(targetWorkspaceIndex) else {
            return
        }

        focusedWorkspaceID = workspaces[targetWorkspaceIndex].id

        guard let sourceColumnIndex = workspaces[workspaceIndex].focusedColumnIndex,
              !workspaces[targetWorkspaceIndex].columns.isEmpty else {
            maintainBottomEmptyWorkspace()
            return
        }

        let targetColumnIndex = min(sourceColumnIndex, workspaces[targetWorkspaceIndex].columns.count - 1)
        workspaces[targetWorkspaceIndex].focusedWindowID = workspaces[targetWorkspaceIndex].columns[targetColumnIndex].windows.first?.id
        revealColumn(at: targetColumnIndex, in: targetWorkspaceIndex, visibleColumnCount: visibleColumnCount)
        maintainBottomEmptyWorkspace()
    }

    private mutating func revealColumn(
        at columnIndex: Int,
        in workspaceIndex: Int,
        visibleColumnCount: Int
    ) {
        let visibleColumnCount = max(visibleColumnCount, 1)
        let currentScrollPosition = Int(workspaces[workspaceIndex].horizontalScrollPosition)
        let lastVisibleColumnIndex = currentScrollPosition + visibleColumnCount - 1

        if columnIndex < currentScrollPosition {
            workspaces[workspaceIndex].horizontalScrollPosition = Double(columnIndex)
        } else if columnIndex > lastVisibleColumnIndex {
            workspaces[workspaceIndex].horizontalScrollPosition = Double(columnIndex - visibleColumnCount + 1)
        }
    }

    private mutating func maintainBottomEmptyWorkspace() {
        let bottomWorkspaceID = workspaces.last?.id

        workspaces.removeAll { workspace in
            workspace.isEmptyWorkspace
                && workspace.id != focusedWorkspaceID
                && workspace.id != bottomWorkspaceID
        }

        if workspaces.last?.isEmptyWorkspace != true {
            let workspaceRoot = workspaces.last?.workspaceRoot ?? FileManager.default.homeDirectoryForCurrentUser
            workspaces.append(.empty(workspaceRoot: workspaceRoot))
        }
    }
}

public struct WorkspaceRailMarker: Identifiable, Equatable, Sendable {
    public var id: Workspace.ID { workspaceID }
    public let workspaceID: Workspace.ID
    public let isActive: Bool
    public let isOccupied: Bool
}

public struct Workspace: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var columns: [Column]
    public var focusedWindowID: WorkspaceWindow.ID?
    public var horizontalScrollPosition: Double
    public var workspaceRoot: URL

    public var isEmptyWorkspace: Bool {
        columns.isEmpty
    }

    public var focusedColumnIndex: Int? {
        guard let focusedWindowID else {
            return nil
        }

        return columns.firstIndex { column in
            column.windows.contains { $0.id == focusedWindowID }
        }
    }

    public static func empty(
        id: UUID = UUID(),
        workspaceRoot: URL
    ) -> Workspace {
        Workspace(
            id: id,
            columns: [],
            focusedWindowID: nil,
            horizontalScrollPosition: 0,
            workspaceRoot: workspaceRoot
        )
    }
}

public struct Column: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var widthMode: ColumnWidthMode
    public var windows: [WorkspaceWindow]
}

public struct WorkspaceWindow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: WindowKind
    public var restoreMetadata: WindowRestoreMetadata
}

public struct WindowRestoreMetadata: Codable, Equatable, Sendable {
    public var browserURL: URL?
    public var terminalCurrentDirectory: URL?
    public var isTerminalExited: Bool

    public static let empty = WindowRestoreMetadata(
        browserURL: nil,
        terminalCurrentDirectory: nil,
        isTerminalExited: false
    )

    public static func initial(for kind: WindowKind) -> WindowRestoreMetadata {
        switch kind {
        case .browser:
            WindowRestoreMetadata(
                browserURL: URL(string: "about:blank"),
                terminalCurrentDirectory: nil,
                isTerminalExited: false
            )
        case .placeholder, .terminal:
            .empty
        }
    }
}

public enum WindowKind: String, Codable, Equatable, Sendable {
    case placeholder
    case terminal
    case browser
}

public enum ColumnWidthMode: String, CaseIterable, Codable, Equatable, Sendable {
    case oneThird
    case half
    case twoThirds
    case full

    mutating func rotateToNextLargerMode() {
        self = switch self {
        case .oneThird:
            .half
        case .half:
            .twoThirds
        case .twoThirds:
            .full
        case .full:
            .oneThird
        }
    }
}

public enum FocusDirection: Equatable, Sendable {
    case left
    case right
    case up
    case down
}
