import AppKit
import NirittyWorkspaceModel

@MainActor
final class WorkspaceShortcutEventMonitor: ObservableObject {
    nonisolated(unsafe) private var monitor: Any?
    private var performWorkspaceCommand: ((WorkspaceCommandID) -> Void)?

    func install(performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void) {
        self.performWorkspaceCommand = performWorkspaceCommand

        guard monitor == nil else {
            return
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let commandID = WorkspaceReservedShortcut.commandID(for: event) else {
                return event
            }

            if !event.isARepeat {
                self.performWorkspaceCommand?(commandID)
            }

            return nil
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
