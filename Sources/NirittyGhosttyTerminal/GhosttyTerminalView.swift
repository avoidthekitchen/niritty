import AppKit
import GhosttyKit
import NirittyWorkspaceModel
import SwiftUI

public struct GhosttyTerminalView: NSViewRepresentable {
    public let window: WorkspaceWindow
    public let isFocused: Bool
    public let focusWindow: () -> Void
    public let updateCurrentDirectory: (URL) -> Void
    public let markExited: () -> Void
    // TODO: Route the restart flow through this representable, or remove this stored closure.
    public let restart: () -> Void
    public let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    public init(
        window: WorkspaceWindow,
        isFocused: Bool,
        focusWindow: @escaping () -> Void,
        updateCurrentDirectory: @escaping (URL) -> Void,
        markExited: @escaping () -> Void,
        restart: @escaping () -> Void,
        performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void
    ) {
        self.window = window
        self.isFocused = isFocused
        self.focusWindow = focusWindow
        self.updateCurrentDirectory = updateCurrentDirectory
        self.markExited = markExited
        self.restart = restart
        self.performWorkspaceCommand = performWorkspaceCommand
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            focusWindow: focusWindow,
            performWorkspaceCommand: performWorkspaceCommand,
            currentDirectoryChanged: updateCurrentDirectory,
            terminalExited: markExited
        )
    }

    public func makeNSView(context: Context) -> TerminalSurfaceView {
        TerminalSurfaceView(
            workingDirectory: window.restoreMetadata.terminalCurrentDirectory,
            coordinator: context.coordinator
        )
    }

    public func updateNSView(_ nsView: TerminalSurfaceView, context: Context) {
        nsView.coordinator = context.coordinator
        nsView.setWorkspaceFocus(isFocused)
        nsView.setNeedsDisplay(nsView.bounds)

        if window.restoreMetadata.isTerminalExited {
            nsView.markHostTerminalExited()
        } else {
            nsView.restartIfExited(workingDirectory: window.restoreMetadata.terminalCurrentDirectory)
        }
    }

    public final class Coordinator {
        let focusWindow: () -> Void
        let performWorkspaceCommand: (WorkspaceCommandID) -> Void
        let lifecycle: TerminalSessionLifecycle

        init(
            focusWindow: @escaping () -> Void,
            performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void,
            currentDirectoryChanged: @escaping (URL) -> Void,
            terminalExited: @escaping () -> Void
        ) {
            self.focusWindow = focusWindow
            self.performWorkspaceCommand = performWorkspaceCommand
            lifecycle = TerminalSessionLifecycle(
                currentDirectoryChanged: currentDirectoryChanged,
                terminalExited: terminalExited
            )
        }
    }
}

public final class TerminalSurfaceView: NSView {
    fileprivate var coordinator: GhosttyTerminalView.Coordinator?

    nonisolated(unsafe) private var surface: ghostty_surface_t?
    private let runtime = GhosttyRuntime.shared
    private var isWorkspaceFocused = false

    init(
        workingDirectory: URL?,
        coordinator: GhosttyTerminalView.Coordinator?
    ) {
        self.coordinator = coordinator
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        wantsLayer = true
        createSurface(workingDirectory: workingDirectory)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let surface {
            ghostty_surface_free(surface)
        }
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isWorkspaceFocused {
            window?.makeFirstResponder(self)
        }
        syncSurfaceSize()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncSurfaceSize()
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let surface else { return }

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        ghostty_surface_set_content_scale(surface, scale, scale)
        syncSurfaceSize()
    }

    public override func becomeFirstResponder() -> Bool {
        focusDidChange(true)
        return true
    }

    public override func resignFirstResponder() -> Bool {
        focusDidChange(false)
        return true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let surface else { return }
        ghostty_surface_draw(surface)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        dispatchWorkspaceShortcut(from: event)
    }

    public override func keyDown(with event: NSEvent) {
        coordinator?.focusWindow()
        setWorkspaceFocus(true)

        if dispatchWorkspaceShortcut(from: event) {
            return
        }

        sendKey(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
    }

    public override func keyUp(with event: NSEvent) {
        sendKey(event, action: GHOSTTY_ACTION_RELEASE)
    }

    public override func mouseDown(with event: NSEvent) {
        coordinator?.focusWindow()
        setWorkspaceFocus(true)
        super.mouseDown(with: event)
    }

    fileprivate func setWorkspaceFocus(_ focused: Bool) {
        isWorkspaceFocused = focused

        if focused {
            window?.makeFirstResponder(self)
        } else if window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }

        focusDidChange(focused)
    }

    fileprivate func updateCurrentDirectory(_ path: String) {
        coordinator?.lifecycle.hostCurrentDirectoryChanged(path)
    }

    fileprivate func markHostTerminalExited() {
        coordinator?.lifecycle.hostChildExited()
    }

    fileprivate func restartIfExited(workingDirectory: URL?) {
        guard coordinator?.lifecycle.shouldRestartSurface(modelIsExited: false) == true else { return }

        if let surface {
            ghostty_surface_free(surface)
            self.surface = nil
        }
        coordinator?.lifecycle.restartRequested()
        createSurface(workingDirectory: workingDirectory)
    }

    private func createSurface(workingDirectory: URL?) {
        guard let app = runtime.app else {
            return
        }

        var config = ghostty_surface_config_new()
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()
        ))
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        config.scale_factor = scale
        config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        let path = workingDirectory?.path()
        surface = path.withCString { workingDirectoryPointer in
            config.working_directory = workingDirectoryPointer
            return ghostty_surface_new(app, &config)
        }

        syncSurfaceSize()
    }

    private func syncSurfaceSize() {
        guard let surface else { return }

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let width = max(UInt32(bounds.width * scale), 1)
        let height = max(UInt32(bounds.height * scale), 1)
        ghostty_surface_set_content_scale(surface, scale, scale)
        ghostty_surface_set_size(surface, width, height)
    }

    private func focusDidChange(_ focused: Bool) {
        guard let surface else { return }
        ghostty_surface_set_focus(surface, focused)
    }

    private func dispatchWorkspaceShortcut(from event: NSEvent) -> Bool {
        guard let commandID = WorkspaceReservedShortcut.commandID(for: event) else {
            return false
        }

        coordinator?.performWorkspaceCommand(commandID)
        return true
    }

    private func sendKey(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }
        var keyEvent = TerminalKeyEventEncoder.ghosttyKeyEvent(from: event, action: action)

        if let text = TerminalKeyEventEncoder.text(for: event) {
            text.withCString { pointer in
                keyEvent.text = pointer
                ghostty_surface_key(surface, keyEvent)
            }
        } else {
            ghostty_surface_key(surface, keyEvent)
        }
        needsDisplay = true
    }
}

private final class GhosttyRuntime {
    nonisolated(unsafe) static let shared = GhosttyRuntime()

    nonisolated(unsafe) private var config: ghostty_config_t?
    nonisolated(unsafe) private(set) var app: ghostty_app_t?

    private init() {
        configureResourcesDirectory()
        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            return
        }

        let config = ghostty_config_new()
        guard let config else { return }
        ghostty_config_load_default_files(config)
        ghostty_config_load_recursive_files(config)
        ghostty_config_finalize(config)
        self.config = config

        var runtimeConfig = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: true,
            wakeup_cb: { userdata in
                GhosttyRuntime.wakeup(userdata)
            },
            action_cb: { _, target, action in
                GhosttyRuntime.handleAction(target: target, action: action)
            },
            read_clipboard_cb: { _, clipboard, state in
                GhosttyRuntime.readClipboard(clipboard, state: state)
            },
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: { _, clipboard, contents, count, _ in
                GhosttyRuntime.writeClipboard(clipboard, contents: contents, count: count)
            },
            close_surface_cb: { _, processAlive in
                if !processAlive {
                    // Surface-specific child-exit state is also delivered through actions.
                }
            }
        )
        self.app = ghostty_app_new(&runtimeConfig, config)
    }

    deinit {
        if let app {
            ghostty_app_free(app)
        }
        if let config {
            ghostty_config_free(config)
        }
    }

    private func configureResourcesDirectory() {
        let fileManager = FileManager.default
        let resourceCandidates = [
            Bundle.main.resourceURL?.appending(path: "ghostty"),
            URL(filePath: fileManager.currentDirectoryPath).appending(path: "Vendor/ghostty/zig-out/share/ghostty")
        ].compactMap { $0 }

        guard let resourcesURL = resourceCandidates.first(where: { fileManager.fileExists(atPath: $0.path()) }) else {
            return
        }

        setenv("GHOSTTY_RESOURCES_DIR", resourcesURL.path(), 0)
    }

    nonisolated private static func wakeup(_ userdata: UnsafeMutableRawPointer?) {
        guard let userdata else { return }
        let runtime = Unmanaged<GhosttyRuntime>.fromOpaque(userdata).takeUnretainedValue()
        guard let app = runtime.app else { return }
        ghostty_app_tick(app)
    }

    nonisolated private static func handleAction(target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        guard target.tag == GHOSTTY_TARGET_SURFACE,
              let surface = target.target.surface,
              let view = ghostty_surface_userdata(surface).map({ Unmanaged<TerminalSurfaceView>.fromOpaque($0).takeUnretainedValue() }) else {
            return false
        }

        switch action.tag {
        case GHOSTTY_ACTION_PWD:
            if let pwd = action.action.pwd.pwd {
                let path = String(cString: pwd)
                DispatchQueue.main.async {
                    view.updateCurrentDirectory(path)
                }
            }
            return true
        case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
            DispatchQueue.main.async {
                view.markHostTerminalExited()
            }
            return true
        default:
            return false
        }
    }

    nonisolated private static func readClipboard(_ clipboard: ghostty_clipboard_e, state: UnsafeMutableRawPointer?) -> Bool {
        guard clipboard == GHOSTTY_CLIPBOARD_STANDARD,
              let string = NSPasteboard.general.string(forType: .string) else {
            return false
        }

        // Minimal MVP: allow paste through normal AppKit text input paths; Ghostty can still ask.
        _ = string
        _ = state
        return false
    }

    nonisolated private static func writeClipboard(
        _ clipboard: ghostty_clipboard_e,
        contents: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int
    ) {
        guard clipboard == GHOSTTY_CLIPBOARD_STANDARD,
              let contents,
              count > 0 else {
            return
        }

        let first = contents[0]
        guard let data = first.data else { return }
        let string = String(cString: data)
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }
}

private extension Optional where Wrapped == String {
    func withCString<T>(_ body: (UnsafePointer<CChar>?) throws -> T) rethrows -> T {
        switch self {
        case .some(let string):
            return try string.withCString(body)
        case .none:
            return try body(nil)
        }
    }
}
