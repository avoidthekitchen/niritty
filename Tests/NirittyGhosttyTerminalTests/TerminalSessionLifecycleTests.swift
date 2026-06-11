import XCTest
@testable import NirittyGhosttyTerminal

final class TerminalSessionLifecycleTests: XCTestCase {
    func testCurrentDirectoryChangesIgnoreEmptyPathsAndReportFileURLs() {
        var reportedDirectories: [URL] = []
        let lifecycle = TerminalSessionLifecycle(
            currentDirectoryChanged: { reportedDirectories.append($0) },
            terminalExited: {}
        )

        lifecycle.hostCurrentDirectoryChanged("")
        lifecycle.hostCurrentDirectoryChanged("/Users/tester/project/Sources")

        XCTAssertEqual(reportedDirectories.map { $0.path() }, ["/Users/tester/project/Sources"])
    }

    func testExitedNotificationIsDeliveredOnceUntilRestarted() {
        var exitCount = 0
        let lifecycle = TerminalSessionLifecycle(
            currentDirectoryChanged: { _ in },
            terminalExited: { exitCount += 1 }
        )

        XCTAssertTrue(lifecycle.hostChildExited())
        XCTAssertFalse(lifecycle.hostChildExited())
        XCTAssertEqual(exitCount, 1)

        XCTAssertTrue(lifecycle.restartRequested())
        XCTAssertTrue(lifecycle.hostChildExited())
        XCTAssertEqual(exitCount, 2)
    }

    func testModelExitedStateCreatesRestartIntentOnlyAfterHostExit() {
        let lifecycle = TerminalSessionLifecycle(
            currentDirectoryChanged: { _ in },
            terminalExited: {}
        )

        XCTAssertFalse(lifecycle.shouldRestartSurface(modelIsExited: false))
        _ = lifecycle.hostChildExited()
        XCTAssertFalse(lifecycle.shouldRestartSurface(modelIsExited: true))
        XCTAssertTrue(lifecycle.shouldRestartSurface(modelIsExited: false))
    }
}
