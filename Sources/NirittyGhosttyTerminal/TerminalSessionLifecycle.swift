import Foundation

final class TerminalSessionLifecycle {
    private let currentDirectoryChanged: (URL) -> Void
    private let terminalExited: () -> Void
    private var didNotifyExited = false

    init(
        currentDirectoryChanged: @escaping (URL) -> Void,
        terminalExited: @escaping () -> Void
    ) {
        self.currentDirectoryChanged = currentDirectoryChanged
        self.terminalExited = terminalExited
    }

    func hostCurrentDirectoryChanged(_ path: String) {
        guard !path.isEmpty else { return }
        currentDirectoryChanged(URL(filePath: path))
    }

    @discardableResult
    func hostChildExited() -> Bool {
        guard !didNotifyExited else { return false }
        didNotifyExited = true
        terminalExited()
        return true
    }

    func shouldRestartSurface(modelIsExited: Bool) -> Bool {
        didNotifyExited && !modelIsExited
    }

    @discardableResult
    func restartRequested() -> Bool {
        guard didNotifyExited else { return false }
        didNotifyExited = false
        return true
    }
}
