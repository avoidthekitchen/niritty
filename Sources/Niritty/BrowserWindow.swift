import AppKit
import Foundation
import NirittyWorkspaceModel
import SwiftUI
import WebKit

struct BrowserWindowContent: View {
    let initialURL: URL
    let focusWindow: () -> Void
    let commitBrowserURL: (URL) -> Void
    let performWorkspaceCommand: (WorkspaceCommandID) -> Void

    @State private var addressText: String
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false

    @StateObject private var browserController: BrowserWindowController

    init(
        initialURL: URL,
        focusWindow: @escaping () -> Void,
        commitBrowserURL: @escaping (URL) -> Void,
        performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void
    ) {
        self.initialURL = initialURL
        self.focusWindow = focusWindow
        self.commitBrowserURL = commitBrowserURL
        self.performWorkspaceCommand = performWorkspaceCommand
        _addressText = State(initialValue: initialURL.absoluteString)
        _browserController = StateObject(wrappedValue: BrowserWindowController(
            initialURL: initialURL,
            focusWindow: focusWindow,
            commitBrowserURL: commitBrowserURL,
            performWorkspaceCommand: performWorkspaceCommand
        ))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button("Back") {
                    focusWindow()
                    browserController.goBack()
                }
                .disabled(!canGoBack)

                Button("Forward") {
                    focusWindow()
                    browserController.goForward()
                }
                .disabled(!canGoForward)

                Button(isLoading ? "Stop" : "Reload") {
                    focusWindow()
                    if isLoading {
                        browserController.stopLoading()
                    } else {
                        browserController.reload()
                    }
                }

                TextField("Address", text: $addressText)
                    .textFieldStyle(.roundedBorder)
                    .onTapGesture {
                        focusWindow()
                    }
                    .onSubmit {
                        focusWindow()
                        guard let url = BrowserAddressNormalizer.normalizedURL(from: addressText) else {
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
            browserController.focusWindow = focusWindow
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
        controller.webView.focusWindow = controller.focusWindow
        controller.webView.performWorkspaceCommand = controller.performWorkspaceCommand
        return controller.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let workspaceWebView = nsView as? WorkspaceShortcutWebView else {
            return
        }
        workspaceWebView.focusWindow = controller.focusWindow
        workspaceWebView.performWorkspaceCommand = controller.performWorkspaceCommand
    }
}

private final class WorkspaceShortcutWebView: WKWebView {
    var focusWindow: (() -> Void)?
    var performWorkspaceCommand: ((WorkspaceCommandID) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if dispatchWorkspaceShortcut(from: event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        focusWindow?()

        if dispatchWorkspaceShortcut(from: event) {
            return
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        focusWindow?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        focusWindow?()
        super.rightMouseDown(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        focusWindow?()
        super.otherMouseDown(with: event)
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

        focusWindow?()

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
    var focusWindow: () -> Void {
        didSet {
            webView.focusWindow = focusWindow
        }
    }
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
        focusWindow: @escaping () -> Void,
        commitBrowserURL: @escaping (URL) -> Void,
        performWorkspaceCommand: @escaping (WorkspaceCommandID) -> Void
    ) {
        self.commitBrowserURL = commitBrowserURL
        self.focusWindow = focusWindow
        self.performWorkspaceCommand = performWorkspaceCommand

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = Self.sharedWebsiteDataStore
        webView = WorkspaceShortcutWebView(frame: .zero, configuration: configuration)
        webView.focusWindow = focusWindow
        webView.performWorkspaceCommand = performWorkspaceCommand

        super.init()

        webView.navigationDelegate = self
        load(initialURL)
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
