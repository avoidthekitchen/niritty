import AppKit
import Foundation
import NirittyWorkspaceModel
import SwiftUI

struct WorkspaceRail: View {
    let markers: [WorkspaceRailMarker]
    let focusWorkspace: (Workspace.ID) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(markers.enumerated()), id: \.element.id) { index, marker in
                Button(action: { focusWorkspace(marker.workspaceID) }) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(markerFill(for: marker))
                            .frame(width: marker.isActive ? 14 : 10, height: marker.isActive ? 14 : 10)

                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(marker.isActive ? Color.primary : Color.secondary)
                    }
                    .frame(width: 32, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Workspace \(index + 1)")
            }
        }
        .padding(.top, 52)
        .frame(width: 40)
    }

    private func markerFill(for marker: WorkspaceRailMarker) -> Color {
        if marker.isActive {
            return .accentColor
        }

        return marker.isOccupied ? Color.primary.opacity(0.55) : Color.secondary.opacity(0.25)
    }
}

struct WorkspaceStrip: View {
    let index: Int
    let workspace: Workspace
    let focusWindow: (WorkspaceWindow.ID) -> Void
    let closeWindow: (WorkspaceWindow.ID) -> Void
    let commitBrowserURL: (URL, WorkspaceWindow.ID) -> Void
    let rotateColumnWidth: (WorkspaceWindow.ID) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void
    let visibleColumnCountChanged: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)

                Text("Workspace \(index + 1)")
                    .font(.headline)

                Text(workspace.isEmptyWorkspace ? "Empty Workspace" : "\(workspace.columns.count) Columns")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            GeometryReader { geometryProxy in
                let visibleColumnCount = visibleColumnCount(for: geometryProxy.size.width)

                ScrollViewReader { horizontalScrollProxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            if workspace.columns.isEmpty {
                                EmptyWorkspacePlaceholder()
                            } else {
                                ForEach(Array(workspace.columns.enumerated()), id: \.element.id) { columnIndex, column in
                                    PlaceholderColumn(
                                        column: column,
                                        index: columnIndex,
                                        availableWidth: geometryProxy.size.width,
                                        focusedWindowID: workspace.focusedWindowID,
                                        focusWindow: focusWindow,
                                        closeWindow: closeWindow,
                                        commitBrowserURL: commitBrowserURL,
                                        rotateColumnWidth: rotateColumnWidth,
                                        performWorkspaceCommand: performWorkspaceCommand
                                    )
                                    .frame(maxHeight: .infinity)
                                    .id(column.id)
                                }
                            }
                        }
                        .padding(2)
                        .frame(minHeight: geometryProxy.size.height, alignment: .topLeading)
                    }
                    .onAppear {
                        visibleColumnCountChanged(visibleColumnCount)
                        if let columnID = restoredColumnID {
                            horizontalScrollProxy.scrollTo(columnID, anchor: .leading)
                        }
                    }
                    .onChange(of: visibleColumnCount) { _, visibleColumnCount in
                        visibleColumnCountChanged(visibleColumnCount)
                    }
                    .onChange(of: workspace.horizontalScrollPosition) { _, _ in
                        if let columnID = restoredColumnID {
                            horizontalScrollProxy.scrollTo(columnID, anchor: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var restoredColumnID: Column.ID? {
        guard !workspace.columns.isEmpty else {
            return nil
        }

        let columnIndex = min(
            max(Int(workspace.horizontalScrollPosition), workspace.columns.startIndex),
            workspace.columns.index(before: workspace.columns.endIndex)
        )
        return workspace.columns[columnIndex].id
    }

    private func visibleColumnCount(for availableWidth: Double) -> Int {
        guard !workspace.columns.isEmpty else {
            return 1
        }

        let startIndex = min(
            max(Int(workspace.horizontalScrollPosition), workspace.columns.startIndex),
            workspace.columns.index(before: workspace.columns.endIndex)
        )
        var occupiedWidth = 0.0
        var columnCount = 0

        for column in workspace.columns[startIndex...] {
            let columnWidth = max(280, availableWidth * column.widthMode.widthFraction)
            let nextOccupiedWidth = occupiedWidth + columnWidth + (columnCount == 0 ? 0 : 12)

            if columnCount > 0 && nextOccupiedWidth > availableWidth {
                break
            }

            occupiedWidth = nextOccupiedWidth
            columnCount += 1
        }

        return max(columnCount, 1)
    }
}

private struct PlaceholderColumn: View {
    let column: Column
    let index: Int
    let availableWidth: Double
    let focusedWindowID: WorkspaceWindow.ID?
    let focusWindow: (WorkspaceWindow.ID) -> Void
    let closeWindow: (WorkspaceWindow.ID) -> Void
    let commitBrowserURL: (URL, WorkspaceWindow.ID) -> Void
    let rotateColumnWidth: (WorkspaceWindow.ID) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Column \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(column.widthMode.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(column.windows) { window in
                ColumnWindowCard(
                    window: window,
                    isFocused: window.id == focusedWindowID,
                    width: max(280, availableWidth * column.widthMode.widthFraction),
                    focusWindow: focusWindow,
                    closeWindow: closeWindow,
                    commitBrowserURL: commitBrowserURL,
                    rotateColumnWidth: rotateColumnWidth,
                    performWorkspaceCommand: performWorkspaceCommand
                )
            }
        }
    }
}

private struct ColumnWindowCard: View {
    let window: WorkspaceWindow
    let isFocused: Bool
    let width: Double
    let focusWindow: (WorkspaceWindow.ID) -> Void
    let closeWindow: (WorkspaceWindow.ID) -> Void
    let commitBrowserURL: (URL, WorkspaceWindow.ID) -> Void
    let rotateColumnWidth: (WorkspaceWindow.ID) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            windowHeader

            WindowContent(
                window: window,
                focusWindow: {
                    focusWindow(window.id)
                },
                commitBrowserURL: { url in
                    commitBrowserURL(url, window.id)
                },
                performWorkspaceCommand: performWorkspaceCommand
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            HStack {
                Spacer()

                Button("Width") {
                    rotateColumnWidth(window.id)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .id(window.id)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var windowHeader: some View {
        HStack {
            Button(action: { focusWindow(window.id) }) {
                Text(window.kind.title)
                    .font(.headline)
            }
            .buttonStyle(.plain)

            Spacer()

            if isFocused {
                Text("Focused")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            Button("Close") {
                closeWindow(window.id)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct WindowContent: View {
    let window: WorkspaceWindow
    let focusWindow: () -> Void
    let commitBrowserURL: (URL) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    var body: some View {
        switch window.kind {
        case .browser:
            BrowserWindowContent(
                initialURL: window.restoreMetadata.browserURL ?? URL(string: "about:blank")!,
                focusWindow: focusWindow,
                commitBrowserURL: commitBrowserURL,
                performWorkspaceCommand: performWorkspaceCommand
            )
        case .placeholder:
            Text("Placeholder Window")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .terminal:
            Text("Terminal Window (placeholder)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct EmptyWorkspacePlaceholder: View {
    var body: some View {
        Text("Empty Workspace")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(width: 280)
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor).opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension WindowKind {
    var title: String {
        switch self {
        case .placeholder:
            "Placeholder"
        case .terminal:
            "Terminal"
        case .browser:
            "Browser"
        }
    }
}

private extension ColumnWidthMode {
    var widthFraction: Double {
        switch self {
        case .oneThird:
            1.0 / 3.0
        case .half:
            0.5
        case .twoThirds:
            2.0 / 3.0
        case .full:
            1.0
        }
    }

    var title: String {
        switch self {
        case .oneThird:
            "1/3"
        case .half:
            "1/2"
        case .twoThirds:
            "2/3"
        case .full:
            "Full"
        }
    }
}
