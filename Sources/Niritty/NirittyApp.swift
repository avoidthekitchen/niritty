import AppKit
import Foundation
import NirittyWorkspaceModel
import SwiftUI

@main
struct NirittyApp: App {
    private let configuration = NirittyAppConfiguration.default

    @Environment(\.scenePhase) private var scenePhase
    @State private var workspaceStack: WorkspaceStack
    @State private var isShortcutOverlayPresented = false
    @State private var visibleColumnCount = 2
    @State private var pendingPersistenceTask: Task<Void, Never>?

    init() {
        _workspaceStack = State(initialValue: Self.loadWorkspaceStack())
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        Window(configuration.appWindowTitle, id: configuration.appWindowIdentifier) {
            AppWindowView(
                workspaceStack: $workspaceStack,
                shortcutOverlayModel: ShortcutOverlayModel(registry: .v1),
                isShortcutOverlayPresented: $isShortcutOverlayPresented,
                visibleColumnCount: $visibleColumnCount
            )
                .frame(minWidth: 900, minHeight: 560)
                .onChange(of: workspaceStack) { _, workspaceStack in
                    scheduleWorkspaceStackSave(workspaceStack)
                }
                .onChange(of: scenePhase) { _, scenePhase in
                    if scenePhase != .active {
                        flushWorkspaceStackSave(workspaceStack)
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Workspace") {
                Button("Focus Left") {
                    performWorkspaceCommand(.focusLeft)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.control, .shift])

                Button("Focus Right") {
                    performWorkspaceCommand(.focusRight)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.control, .shift])

                Button("Focus Up") {
                    performWorkspaceCommand(.focusUp)
                }
                .keyboardShortcut(.upArrow, modifiers: [.control, .shift])

                Button("Focus Down") {
                    performWorkspaceCommand(.focusDown)
                }
                .keyboardShortcut(.downArrow, modifiers: [.control, .shift])

                Divider()

                Button("Move Column Left") {
                    performWorkspaceCommand(.moveColumnLeft)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.control, .shift, .command])

                Button("Move Column Right") {
                    performWorkspaceCommand(.moveColumnRight)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.control, .shift, .command])

                Button("Transfer Column Up") {
                    performWorkspaceCommand(.transferColumnUp)
                }
                .keyboardShortcut(.upArrow, modifiers: [.control, .shift, .command])

                Button("Transfer Column Down") {
                    performWorkspaceCommand(.transferColumnDown)
                }
                .keyboardShortcut(.downArrow, modifiers: [.control, .shift, .command])

                Divider()

                Button("Shortcut Overlay") {
                    performWorkspaceCommand(.showShortcutOverlay)
                }
                .keyboardShortcut("/", modifiers: [.control, .shift])
            }
        }
    }

    private func performWorkspaceCommand(_ commandID: WorkspaceCommandID) {
        executeWorkspaceCommand(
            commandID,
            workspaceStack: &workspaceStack,
            isShortcutOverlayPresented: &isShortcutOverlayPresented,
            visibleColumnCount: visibleColumnCount
        )
    }

    private func scheduleWorkspaceStackSave(_ workspaceStack: WorkspaceStack) {
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else {
                return
            }

            Self.saveWorkspaceStack(workspaceStack)
        }
    }

    private func flushWorkspaceStackSave(_ workspaceStack: WorkspaceStack) {
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = nil
        Self.saveWorkspaceStack(workspaceStack)
    }

    private static func loadWorkspaceStack() -> WorkspaceStack {
        let workspaceRoot = FileManager.default.homeDirectoryForCurrentUser

        guard let data = try? Data(contentsOf: persistenceURL),
              let snapshot = try? JSONDecoder().decode(WorkspaceStackSnapshot.self, from: data) else {
            return .initial(workspaceRoot: workspaceRoot)
        }

        return .restore(from: snapshot, defaultWorkspaceRoot: workspaceRoot)
    }

    private static func saveWorkspaceStack(_ workspaceStack: WorkspaceStack) {
        do {
            let data = try JSONEncoder().encode(WorkspaceStackSnapshot(stack: workspaceStack))
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist Workspace Stack: \(error)")
        }
    }

    private static var persistenceURL: URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return applicationSupportURL
            .appending(path: "Niritty", directoryHint: .isDirectory)
            .appending(path: "WorkspaceStack.json")
    }
}
