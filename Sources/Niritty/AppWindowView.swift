import NirittyWorkspaceModel
import SwiftUI

struct AppWindowView: View {
    @Binding var workspaceStack: WorkspaceStack
    let shortcutOverlayModel: ShortcutOverlayModel
    @Binding var isShortcutOverlayPresented: Bool
    @Binding var visibleColumnCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            WorkspaceRail(
                markers: workspaceStack.workspaceRailMarkers,
                focusWorkspace: { workspaceID in
                    workspaceStack.focusWorkspace(id: workspaceID)
                }
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workspace Stack")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(statusText)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack {
                        Button("New Terminal Window") {
                            workspaceStack.createWindow(kind: .terminal)
                        }

                        Button("New Browser Window") {
                            workspaceStack.createWindow(kind: .browser)
                        }

                        Button("Shortcuts") {
                            isShortcutOverlayPresented = true
                        }
                    }
                }

                if let focusedWorkspace = focusedWorkspace {
                    WorkspaceStrip(
                        index: focusedWorkspace.offset,
                        workspace: focusedWorkspace.element,
                        focusWindow: { windowID in
                            workspaceStack.focusWindow(id: windowID)
                        },
                        closeWindow: { windowID in
                            workspaceStack.closeWindow(id: windowID)
                        },
                        commitBrowserURL: { url, windowID in
                            workspaceStack.commitBrowserURL(url, for: windowID)
                        },
                        rotateColumnWidth: { windowID in
                            workspaceStack.focusWindow(id: windowID)
                            workspaceStack.rotateFocusedColumnWidth()
                        },
                        performWorkspaceCommand: { commandID in
                            performWorkspaceCommand(commandID)
                        },
                        visibleColumnCountChanged: { visibleColumnCount in
                            self.visibleColumnCount = visibleColumnCount
                        },
                        horizontalScrollPositionChanged: { horizontalScrollPosition in
                            workspaceStack.setHorizontalScrollPosition(
                                horizontalScrollPosition,
                                for: focusedWorkspace.element.id
                            )
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .sheet(isPresented: $isShortcutOverlayPresented) {
            ShortcutOverlayView(model: shortcutOverlayModel)
        }
    }

    private var focusedWorkspace: EnumeratedSequence<[Workspace]>.Element? {
        Array(workspaceStack.workspaces.enumerated()).first { _, workspace in
            workspace.id == workspaceStack.focusedWorkspaceID
        }
    }

    private var statusText: String {
        let workspaceCount = workspaceStack.workspaces.count
        let label = workspaceCount == 1 ? "Workspace" : "Workspaces"
        return "\(workspaceCount) \(label) - one Empty Workspace"
    }

    private func performWorkspaceCommand(_ commandID: WorkspaceCommandID) {
        executeWorkspaceCommand(
            commandID,
            workspaceStack: &workspaceStack,
            isShortcutOverlayPresented: &isShortcutOverlayPresented,
            visibleColumnCount: visibleColumnCount
        )
    }
}
