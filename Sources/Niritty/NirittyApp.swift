import AppKit
import Foundation
import NirittyWorkspaceModel
import OSLog
import SwiftUI
import WebKit

private enum NirittyTelemetry {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.niritty.Niritty"

    static let workspace = Logger(subsystem: subsystem, category: "Workspace")
}

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

private func executeWorkspaceCommand(
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

private enum WorkspaceReservedShortcut {
    private static let workspaceModifierFlags: NSEvent.ModifierFlags = [.control, .shift]
    private static let movementModifierFlags: NSEvent.ModifierFlags = [.control, .shift, .command]
    private static let comparedModifierFlags: NSEvent.ModifierFlags = [.control, .shift, .command, .option]

    static func commandID(for event: NSEvent) -> WorkspaceCommandID? {
        guard event.type == .keyDown else {
            return nil
        }

        let modifiers = event.modifierFlags.intersection(comparedModifierFlags)

        if modifiers == workspaceModifierFlags {
            switch event.keyCode {
            case 123:
                return .focusLeft
            case 124:
                return .focusRight
            case 126:
                return .focusUp
            case 125:
                return .focusDown
            default:
                if event.charactersIgnoringModifiers == "/" {
                    return .showShortcutOverlay
                }
            }
        }

        if modifiers == movementModifierFlags {
            switch event.keyCode {
            case 123:
                return .moveColumnLeft
            case 124:
                return .moveColumnRight
            case 126:
                return .transferColumnUp
            case 125:
                return .transferColumnDown
            default:
                return nil
            }
        }

        return nil
    }
}

private extension WorkspaceCommandID {
    var telemetryName: String {
        rawValue
    }
}

private struct ShortcutOverlayView: View {
    let model: ShortcutOverlayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Shortcut Overlay")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.rows, id: \.commandTitle) { row in
                    HStack {
                        Text(row.commandTitle)
                            .frame(minWidth: 180, alignment: .leading)

                        Text(row.shortcutText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct WorkspaceRail: View {
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

private struct WorkspaceStrip: View {
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
    let commitBrowserURL: (URL) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    var body: some View {
        switch window.kind {
        case .browser:
            BrowserWindowContent(
                initialURL: window.restoreMetadata.browserURL ?? URL(string: "about:blank")!,
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

private struct BrowserWindowContent: View {
    let initialURL: URL
    let commitBrowserURL: (URL) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    @State private var addressText: String
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false

    @StateObject private var browserController: BrowserWindowController

    init(
        initialURL: URL,
        commitBrowserURL: @escaping (URL) -> Void,
        performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void
    ) {
        self.initialURL = initialURL
        self.commitBrowserURL = commitBrowserURL
        self.performWorkspaceCommand = performWorkspaceCommand
        _addressText = State(initialValue: initialURL.absoluteString)
        _browserController = StateObject(wrappedValue: BrowserWindowController(
            initialURL: initialURL,
            commitBrowserURL: commitBrowserURL,
            performWorkspaceCommand: performWorkspaceCommand
        ))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button("Back") {
                    browserController.goBack()
                }
                .disabled(!canGoBack)

                Button("Forward") {
                    browserController.goForward()
                }
                .disabled(!canGoForward)

                Button(isLoading ? "Stop" : "Reload") {
                    if isLoading {
                        browserController.stopLoading()
                    } else {
                        browserController.reload()
                    }
                }

                TextField("Address", text: $addressText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard let url = BrowserWindowController.normalizedURL(from: addressText) else {
                            return
                        }

                        browserController.load(url)
                    }
            }

            BrowserWebView(controller: browserController)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            browserController.performWorkspaceCommand = performWorkspaceCommand
        }
        .onReceive(browserController.$committedURL.compactMap { $0 }) { url in
            addressText = url.absoluteString
        }
        .onReceive(browserController.$canGoBack) { canGoBack = $0 }
        .onReceive(browserController.$canGoForward) { canGoForward = $0 }
        .onReceive(browserController.$isLoading) { isLoading = $0 }
    }
}

private struct BrowserWebView: NSViewRepresentable {
    let controller: BrowserWindowController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView.performWorkspaceCommand = controller.performWorkspaceCommand
        return controller.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let workspaceWebView = nsView as? WorkspaceShortcutWebView else {
            return
        }
        workspaceWebView.performWorkspaceCommand = controller.performWorkspaceCommand
    }
}

private final class WorkspaceShortcutWebView: WKWebView {
    var performWorkspaceCommand: ((WorkspaceCommandID) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if dispatchWorkspaceShortcut(from: event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if dispatchWorkspaceShortcut(from: event) {
            return
        }

        super.keyDown(with: event)
    }

    override func doCommand(by selector: Selector) {
        if let event = NSApp.currentEvent,
           dispatchWorkspaceShortcut(from: event) {
            return
        }

        super.doCommand(by: selector)
    }

    private func dispatchWorkspaceShortcut(from event: NSEvent) -> Bool {
        guard let commandID = WorkspaceReservedShortcut.commandID(for: event),
              let performWorkspaceCommand else {
            return false
        }

        if !event.isARepeat {
            performWorkspaceCommand(commandID)
        }

        return true
    }
}

@MainActor
private final class BrowserWindowController: NSObject, ObservableObject, WKNavigationDelegate {
    static let sharedWebsiteDataStore = WKWebsiteDataStore.default()

    let webView: WorkspaceShortcutWebView
    private let commitBrowserURL: (URL) -> Void
    var performWorkspaceCommand: (WorkspaceCommandID) -> Void {
        didSet {
            webView.performWorkspaceCommand = performWorkspaceCommand
        }
    }

    @Published var committedURL: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false

    init(
        initialURL: URL,
        commitBrowserURL: @escaping (URL) -> Void,
        performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void
    ) {
        self.commitBrowserURL = commitBrowserURL
        self.performWorkspaceCommand = performWorkspaceCommand

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = Self.sharedWebsiteDataStore
        webView = WorkspaceShortcutWebView(frame: .zero, configuration: configuration)
        webView.performWorkspaceCommand = performWorkspaceCommand

        super.init()

        webView.navigationDelegate = self
        load(initialURL)
    }

    static func normalizedURL(from addressText: String) -> URL? {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed == "about:blank" {
            return URL(string: "about:blank")
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    func load(_ url: URL) {
        if url.absoluteString == "about:blank" {
            webView.loadHTMLString("", baseURL: url)
            commit(url)
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url {
            commit(url)
        }
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            commit(url)
        }
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
    }

    private func commit(_ url: URL) {
        guard committedURL != url else {
            updateNavigationState()
            return
        }

        committedURL = url
        commitBrowserURL(url)
        updateNavigationState()
    }

    private func updateNavigationState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
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
