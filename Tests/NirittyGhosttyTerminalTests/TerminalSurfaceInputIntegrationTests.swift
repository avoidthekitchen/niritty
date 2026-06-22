import AppKit
import XCTest
@testable import NirittyGhosttyTerminal

@MainActor
final class TerminalSurfaceInputIntegrationTests: XCTestCase {
    private let prompt = "NIRITTY_PROMPT> "

    func testPlainBackspaceWritesDelByteToPty() throws {
        let harness = try makeCaptureHarness()
        defer { harness.cleanup() }

        XCTAssertTrue(harness.view.debugSendSyntheticKeyPressAndReleaseForTesting(
            keyCode: 11,
            characters: "b"
        ))
        XCTAssertTrue(harness.view.debugSendSyntheticKeyPressAndReleaseForTesting(
            keyCode: 51,
            characters: "\u{7F}"
        ))

        let capturedHex = try waitForFileContents(at: harness.outputURL, timeout: 5)
        XCTAssertEqual(capturedHex, "627f")
    }

    func testMonitoredBackspaceDeletesCharacterInInteractiveZshPrompt() throws {
        let harness = makeTerminalHarness(
            command: "/usr/bin/env TERM=xterm-256color PROMPT=\(shellSingleQuoted(prompt)) /bin/zsh -f -i"
        )
        defer { harness.cleanup() }

        let promptText = waitForVisibleText(in: harness.view, timeout: 5) { $0.contains(prompt) }
        XCTAssertTrue(
            promptText != nil,
            "Expected interactive zsh prompt before sending input. Visible text: \(harness.view.debugVisibleTextForTesting())"
        )

        XCTAssertTrue(harness.view.debugSendSyntheticKeyPressAndReleaseForTesting(
            keyCode: 11,
            characters: "b"
        ))

        let delete = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: harness.window.windowNumber,
            context: nil,
            characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}",
            isARepeat: false,
            keyCode: 51
        ))
        XCTAssertNil(harness.view.debugHandleMonitoredKeyDownForTesting(delete))
        XCTAssertTrue(harness.view.debugWouldConsumeDuplicateMonitoredDeleteForTesting(delete))

        let textAfterDelete = try XCTUnwrap(waitForVisibleText(
            in: harness.view,
            timeout: 5,
            matching: { visibleText in
                guard let promptLine = visibleText
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .last(where: { $0.contains(prompt) }) else {
                    return false
                }
                return !promptLine.contains("b")
            }
        ))
        XCTAssertFalse(textAfterDelete.contains("\(prompt)b"), textAfterDelete)

        typeText("echo NIRITTY_DELETE_OK", in: harness.view)
        XCTAssertTrue(harness.view.debugSendSyntheticKeyPressAndReleaseForTesting(
            keyCode: 36,
            characters: "\r"
        ))

        let finalText = try XCTUnwrap(waitForVisibleText(
            in: harness.view,
            timeout: 5,
            matching: { $0.contains("NIRITTY_DELETE_OK") || $0.contains("becho") }
        ))
        XCTAssertTrue(finalText.contains("NIRITTY_DELETE_OK"), finalText)
        XCTAssertFalse(finalText.contains("becho"), finalText)
    }

    func testMonitorDoesNotConsumeDeleteWhenTerminalIsNotFirstResponder() throws {
        let harness = try makeCaptureHarness()
        defer { harness.cleanup() }

        XCTAssertTrue(harness.view.debugSendSyntheticKeyPressAndReleaseForTesting(
            keyCode: 11,
            characters: "b"
        ))

        let alternateResponder = FocusableView(frame: harness.view.bounds)
        harness.window.contentView?.addSubview(alternateResponder)
        harness.window.makeFirstResponder(alternateResponder)
        XCTAssertTrue(harness.window.firstResponder === alternateResponder)

        let delete = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: harness.window.windowNumber,
            context: nil,
            characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}",
            isARepeat: false,
            keyCode: 51
        ))

        XCTAssertTrue(harness.view.debugHandleMonitoredKeyDownForTesting(delete) === delete)
        XCTAssertFalse(harness.view.debugWouldConsumeDuplicateMonitoredDeleteForTesting(delete))
    }

    func testMonitoredBackspaceWritesDelByteToPtyAndSuppressesDuplicateKeyDown() throws {
        let harness = try makeCaptureHarness()
        defer { harness.cleanup() }

        XCTAssertTrue(harness.view.debugSendSyntheticKeyPressAndReleaseForTesting(
            keyCode: 11,
            characters: "b"
        ))

        let timestamp = ProcessInfo.processInfo.systemUptime
        let delete = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: timestamp,
            windowNumber: harness.window.windowNumber,
            context: nil,
            characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}",
            isARepeat: false,
            keyCode: 51
        ))

        XCTAssertNil(
            harness.view.debugHandleMonitoredKeyDownForTesting(delete),
            "Focused Delete should be consumed by the local monitor path"
        )
        XCTAssertTrue(
            harness.view.debugWouldConsumeDuplicateMonitoredDeleteForTesting(delete),
            "The matching keyDown should be marked as already routed"
        )

        let capturedHex = try waitForFileContents(at: harness.outputURL, timeout: 5)
        XCTAssertEqual(capturedHex, "627f")
    }

    private struct CaptureHarness {
        let view: TerminalSurfaceView
        let window: NSWindow
        let outputURL: URL
        let cleanup: () -> Void
    }

    private func makeCaptureHarness() throws -> CaptureHarness {
        _ = NSApplication.shared

        let tempDirectory = FileManager.default.temporaryDirectory
            .appending(path: "niritty-terminal-input-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let scriptURL = tempDirectory.appending(path: "capture.py")
        let readyURL = tempDirectory.appending(path: "ready")
        let outputURL = tempDirectory.appending(path: "output")
        try captureScript(readyPath: readyURL.path(), outputPath: outputURL.path())
            .write(to: scriptURL, atomically: true, encoding: .utf8)

        let command = "/usr/bin/python3 \(shellSingleQuoted(scriptURL.path()))"
        let view = TerminalSurfaceView(
            workingDirectory: tempDirectory,
            coordinator: nil,
            command: command
        )
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        XCTAssertTrue(
            waitForFile(at: readyURL, timeout: 5),
            "Expected capture process to report ready before sending terminal input"
        )

        return CaptureHarness(
            view: view,
            window: window,
            outputURL: outputURL,
            cleanup: {
                window.orderOut(nil)
                try? FileManager.default.removeItem(at: tempDirectory)
            }
        )
    }

    private struct TerminalHarness {
        let view: TerminalSurfaceView
        let window: NSWindow
        let cleanup: () -> Void
    }

    private func makeTerminalHarness(command: String) -> TerminalHarness {
        _ = NSApplication.shared

        let tempDirectory = FileManager.default.temporaryDirectory
            .appending(path: "niritty-terminal-shell-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let view = TerminalSurfaceView(
            workingDirectory: tempDirectory,
            coordinator: nil,
            command: command
        )
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        return TerminalHarness(
            view: view,
            window: window,
            cleanup: {
                window.orderOut(nil)
                try? FileManager.default.removeItem(at: tempDirectory)
            }
        )
    }

    private func typeText(_ text: String, in view: TerminalSurfaceView) {
        for character in text {
            let string = String(character)
            let keyCode: UInt16 = string == " " ? 49 : 0
            XCTAssertTrue(view.debugSendSyntheticKeyPressAndReleaseForTesting(
                keyCode: keyCode,
                characters: string
            ))
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func waitForVisibleText(
        in view: TerminalSurfaceView,
        timeout: TimeInterval,
        matching predicate: (String) -> Bool
    ) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let text = view.debugVisibleTextForTesting()
            if predicate(text) {
                return text
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let text = view.debugVisibleTextForTesting()
        return predicate(text) ? text : nil
    }

    private func captureScript(readyPath: String, outputPath: String) -> String {
        """
        import os
        import select
        import sys
        import termios
        import time
        import tty

        ready_path = \(pythonStringLiteral(readyPath))
        output_path = \(pythonStringLiteral(outputPath))
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)

        try:
            tty.setraw(fd)
            with open(ready_path, "w", encoding="utf-8") as ready:
                ready.write("ready")
                ready.flush()

            data = bytearray()
            deadline = time.monotonic() + 5.0
            while len(data) < 2 and time.monotonic() < deadline:
                readable, _, _ = select.select([fd], [], [], 0.1)
                if readable:
                    data.extend(os.read(fd, 16))

            with open(output_path, "w", encoding="utf-8") as output:
                output.write(bytes(data[:2]).hex())
                output.flush()
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        """
    }

    private func waitForFile(at url: URL, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path()) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }

    private func waitForFileContents(at url: URL, timeout: TimeInterval) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = try? String(contentsOf: url, encoding: .utf8), !value.isEmpty {
                return value
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if FileManager.default.fileExists(atPath: url.path()) {
            return try String(contentsOf: url, encoding: .utf8)
        }
        return ""
    }

    private func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func pythonStringLiteral(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

private final class FocusableView: NSView {
    override var acceptsFirstResponder: Bool {
        true
    }
}
