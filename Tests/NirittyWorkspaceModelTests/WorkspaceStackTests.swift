import XCTest
@testable import NirittyWorkspaceModel

final class WorkspaceStackTests: XCTestCase {
    func testInitialWorkspaceStackContainsOneEmptyWorkspace() {
        let stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester"))

        XCTAssertEqual(stack.workspaces.count, 1)
        XCTAssertEqual(stack.workspaces.first?.workspaceRoot.path(), "/Users/tester")
        XCTAssertTrue(stack.workspaces.first?.isEmptyWorkspace == true)
        XCTAssertEqual(stack.focusedWorkspaceID, stack.workspaces.first?.id)
    }

    func testAppConfigurationDefinesOneAppWindow() {
        let configuration = NirittyAppConfiguration.default

        XCTAssertEqual(configuration.appWindowCount, 1)
        XCTAssertEqual(configuration.appWindowTitle, "Niritty")
    }

    func testCreatingWindowInBottomEmptyWorkspaceAddsNewEmptyWorkspaceBelowIt() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        let originalWorkspaceID = stack.focusedWorkspaceID

        stack.createWindow(kind: .placeholder)

        XCTAssertEqual(stack.workspaces.count, 2)
        XCTAssertEqual(stack.workspaces[0].id, originalWorkspaceID)
        XCTAssertFalse(stack.workspaces[0].isEmptyWorkspace)
        XCTAssertEqual(stack.workspaces[0].columns.count, 1)
        XCTAssertEqual(stack.workspaces[0].columns[0].windows.first?.kind, .placeholder)
        XCTAssertTrue(stack.workspaces[1].isEmptyWorkspace)
        XCTAssertEqual(stack.focusedWorkspaceID, originalWorkspaceID)
    }

    func testExtraEmptyWorkspacesAreRemovedWhenNoLongerFocused() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .placeholder)
        let nonEmptyWorkspaceID = stack.workspaces[0].id
        let extraEmptyWorkspace = Workspace.empty(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.workspaces.append(extraEmptyWorkspace)
        stack.focusedWorkspaceID = extraEmptyWorkspace.id

        stack.focusWorkspace(id: nonEmptyWorkspaceID)

        XCTAssertEqual(stack.workspaces.count, 2)
        XCTAssertEqual(stack.workspaces[0].id, nonEmptyWorkspaceID)
        XCTAssertFalse(stack.workspaces[0].isEmptyWorkspace)
        XCTAssertTrue(stack.workspaces[1].isEmptyWorkspace)
        XCTAssertEqual(stack.focusedWorkspaceID, nonEmptyWorkspaceID)
    }

    func testCreatingTerminalWindowInEmptyWorkspaceCreatesFocusedFirstColumn() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))

        stack.createWindow(kind: .terminal)

        XCTAssertEqual(stack.workspaces[0].columns.count, 1)
        XCTAssertEqual(stack.workspaces[0].columns[0].windows.first?.kind, .terminal)
        XCTAssertEqual(stack.workspaces[0].focusedWindowID, stack.workspaces[0].columns[0].windows.first?.id)
    }

    func testCreatingWindowInNonEmptyWorkspaceInsertsColumnToRightOfFocusedWindow() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let secondWindowID = stack.workspaces[0].columns[1].windows[0].id

        stack.focusWindow(id: firstWindowID)
        stack.createWindow(kind: .terminal)

        XCTAssertEqual(stack.workspaces[0].columns.map { $0.windows[0].id }, [
            firstWindowID,
            stack.workspaces[0].focusedWindowID,
            secondWindowID,
        ])
        XCTAssertEqual(stack.workspaces[0].columns[1].windows[0].kind, .terminal)
    }

    func testClosingFocusedWindowInMultiColumnWorkspaceFocusesNextColumn() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let secondWindowID = stack.workspaces[0].columns[1].windows[0].id
        stack.createWindow(kind: .terminal)
        let thirdWindowID = stack.workspaces[0].columns[2].windows[0].id

        stack.focusWindow(id: secondWindowID)
        stack.closeWindow(id: secondWindowID)

        XCTAssertEqual(stack.workspaces[0].columns.map { $0.windows[0].id }, [
            firstWindowID,
            thirdWindowID,
        ])
        XCTAssertEqual(stack.workspaces[0].focusedWindowID, thirdWindowID)
        XCTAssertEqual(stack.focusedWorkspaceID, stack.workspaces[0].id)
    }

    func testClosingLastWindowInFocusedWorkspaceLeavesFocusedEmptyWorkspaceAndBottomEmptyWorkspace() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let focusedWorkspaceID = stack.workspaces[0].id
        let windowID = stack.workspaces[0].columns[0].windows[0].id

        stack.closeWindow(id: windowID)

        XCTAssertEqual(stack.workspaces.count, 2)
        XCTAssertEqual(stack.focusedWorkspaceID, focusedWorkspaceID)
        XCTAssertEqual(stack.workspaces[0].id, focusedWorkspaceID)
        XCTAssertTrue(stack.workspaces[0].isEmptyWorkspace)
        XCTAssertNil(stack.workspaces[0].focusedWindowID)
        XCTAssertTrue(stack.workspaces[1].isEmptyWorkspace)
    }

    func testClosingNonFocusedWindowKeepsCurrentFocus() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let secondWindowID = stack.workspaces[0].columns[1].windows[0].id
        stack.createWindow(kind: .terminal)
        let thirdWindowID = stack.workspaces[0].columns[2].windows[0].id

        stack.focusWindow(id: firstWindowID)
        stack.closeWindow(id: thirdWindowID)

        XCTAssertEqual(stack.workspaces[0].columns.map { $0.windows[0].id }, [
            firstWindowID,
            secondWindowID,
        ])
        XCTAssertEqual(stack.workspaces[0].focusedWindowID, firstWindowID)
    }

    func testFocusMovesLeftAndRightAcrossColumnsInCurrentWorkspace() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let secondWindowID = stack.workspaces[0].columns[1].windows[0].id

        stack.moveFocus(.left, visibleColumnCount: 1)

        XCTAssertEqual(stack.workspaces[0].focusedWindowID, firstWindowID)
        XCTAssertEqual(stack.workspaces[0].horizontalScrollPosition, 0)

        stack.moveFocus(.right, visibleColumnCount: 1)

        XCTAssertEqual(stack.workspaces[0].focusedWindowID, secondWindowID)
        XCTAssertEqual(stack.workspaces[0].horizontalScrollPosition, 1)
    }

    func testVerticalFocusCrossingTargetsSameColumnIndexWhenAvailable() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        stack.createWindow(kind: .browser)
        let topWorkspaceID = stack.workspaces[0].id
        let topSecondWindowID = stack.workspaces[0].columns[1].windows[0].id
        let bottomWorkspaceID = stack.workspaces[1].id

        stack.focusWorkspace(id: bottomWorkspaceID)
        stack.createWindow(kind: .terminal)
        stack.createWindow(kind: .browser)
        let bottomSecondWindowID = stack.workspaces[1].columns[1].windows[0].id
        stack.focusWindow(id: topSecondWindowID)

        stack.moveFocus(.down, visibleColumnCount: 1)

        XCTAssertEqual(stack.focusedWorkspaceID, bottomWorkspaceID)
        XCTAssertEqual(stack.workspaces[1].focusedWindowID, bottomSecondWindowID)
        XCTAssertEqual(stack.workspaces[1].horizontalScrollPosition, 1)
        XCTAssertEqual(stack.workspaces[0].id, topWorkspaceID)
    }

    func testVerticalFocusCrossingFallsBackToNearestColumnIndex() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        stack.createWindow(kind: .browser)
        stack.createWindow(kind: .terminal)
        let topThirdWindowID = stack.workspaces[0].columns[2].windows[0].id
        let bottomWorkspaceID = stack.workspaces[1].id

        stack.focusWorkspace(id: bottomWorkspaceID)
        stack.createWindow(kind: .browser)
        let bottomOnlyWindowID = stack.workspaces[1].columns[0].windows[0].id
        stack.focusWindow(id: topThirdWindowID)

        stack.moveFocus(.down, visibleColumnCount: 2)

        XCTAssertEqual(stack.focusedWorkspaceID, bottomWorkspaceID)
        XCTAssertEqual(stack.workspaces[1].focusedWindowID, bottomOnlyWindowID)
        XCTAssertEqual(stack.workspaces[1].horizontalScrollPosition, 0)
    }

    func testWorkspaceRemembersFocusedWindowWhenRefocused() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let topWorkspaceID = stack.workspaces[0].id
        let bottomWorkspaceID = stack.workspaces[1].id

        stack.focusWindow(id: firstWindowID)
        stack.focusWorkspace(id: bottomWorkspaceID)
        stack.focusWorkspace(id: topWorkspaceID)

        XCTAssertEqual(stack.workspaces[0].focusedWindowID, firstWindowID)
    }

    func testRevealKeepsScrollPositionWhenFocusedColumnIsAlreadyVisible() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        stack.createWindow(kind: .browser)

        stack.moveFocus(.left, visibleColumnCount: 2)
        stack.moveFocus(.right, visibleColumnCount: 2)

        XCTAssertEqual(stack.workspaces[0].horizontalScrollPosition, 0)
    }

    func testColumnMovementReordersFocusedColumnAndFocusFollowsIt() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let secondWindowID = stack.workspaces[0].columns[1].windows[0].id

        stack.moveFocusedColumn(.left, visibleColumnCount: 2)

        XCTAssertEqual(stack.workspaces[0].columns.map { $0.windows[0].id }, [
            secondWindowID,
            firstWindowID,
        ])
        XCTAssertEqual(stack.workspaces[0].focusedWindowID, secondWindowID)
        XCTAssertEqual(stack.workspaces[0].horizontalScrollPosition, 0)
    }

    func testColumnTransferMovesFocusedColumnToAdjacentWorkspaceAndFocusFollowsIt() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let firstWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.createWindow(kind: .browser)
        let transferredWindowID = stack.workspaces[0].columns[1].windows[0].id

        stack.moveFocusedColumn(.down, visibleColumnCount: 2)

        XCTAssertEqual(stack.workspaces.count, 3)
        XCTAssertEqual(stack.workspaces[0].columns.map { $0.windows[0].id }, [firstWindowID])
        XCTAssertEqual(stack.workspaces[1].columns.map { $0.windows[0].id }, [transferredWindowID])
        XCTAssertEqual(stack.focusedWorkspaceID, stack.workspaces[1].id)
        XCTAssertEqual(stack.workspaces[1].focusedWindowID, transferredWindowID)
        XCTAssertTrue(stack.workspaces[2].isEmptyWorkspace)
    }

    func testColumnTransferCleansUpEmptySourceWorkspaceAndKeepsOneBottomEmptyWorkspace() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let transferredWindowID = stack.workspaces[0].columns[0].windows[0].id

        stack.moveFocusedColumn(.down, visibleColumnCount: 2)

        XCTAssertEqual(stack.workspaces.count, 2)
        XCTAssertEqual(stack.workspaces[0].columns.map { $0.windows[0].id }, [transferredWindowID])
        XCTAssertEqual(stack.focusedWorkspaceID, stack.workspaces[0].id)
        XCTAssertTrue(stack.workspaces[1].isEmptyWorkspace)
    }

    func testColumnsDefaultToHalfWidthAndRotateThroughWidthModes() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)

        XCTAssertEqual(stack.workspaces[0].columns[0].widthMode, .half)

        stack.rotateFocusedColumnWidth()
        XCTAssertEqual(stack.workspaces[0].columns[0].widthMode, .twoThirds)

        stack.rotateFocusedColumnWidth()
        XCTAssertEqual(stack.workspaces[0].columns[0].widthMode, .full)

        stack.rotateFocusedColumnWidth()
        XCTAssertEqual(stack.workspaces[0].columns[0].widthMode, .oneThird)
    }

    func testWorkspaceRailMarkersShowActiveAndOccupancyStateIncludingBottomEmptyWorkspace() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)

        let markers = stack.workspaceRailMarkers

        XCTAssertEqual(markers.count, 2)
        XCTAssertEqual(markers[0].workspaceID, stack.workspaces[0].id)
        XCTAssertTrue(markers[0].isActive)
        XCTAssertTrue(markers[0].isOccupied)
        XCTAssertEqual(markers[1].workspaceID, stack.workspaces[1].id)
        XCTAssertFalse(markers[1].isActive)
        XCTAssertFalse(markers[1].isOccupied)
    }

    func testWorkspaceRailMarkerClickFocusesWorkspace() {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let bottomEmptyMarker = stack.workspaceRailMarkers[1]

        stack.focusWorkspace(id: bottomEmptyMarker.workspaceID)

        XCTAssertEqual(stack.focusedWorkspaceID, bottomEmptyMarker.workspaceID)
        XCTAssertTrue(stack.workspaceRailMarkers[1].isActive)
    }

    func testWorkspaceCommandRegistryContainsFixedV1Shortcuts() {
        let commands = WorkspaceCommandRegistry.v1.commands

        XCTAssertEqual(commands.first(where: { $0.id == .focusLeft })?.shortcut.displayText, "Ctrl+Shift+Left")
        XCTAssertEqual(commands.first(where: { $0.id == .focusRight })?.shortcut.displayText, "Ctrl+Shift+Right")
        XCTAssertEqual(commands.first(where: { $0.id == .focusUp })?.shortcut.displayText, "Ctrl+Shift+Up")
        XCTAssertEqual(commands.first(where: { $0.id == .focusDown })?.shortcut.displayText, "Ctrl+Shift+Down")
        XCTAssertEqual(commands.first(where: { $0.id == .moveColumnLeft })?.shortcut.displayText, "Ctrl+Shift+Command+Left")
        XCTAssertEqual(commands.first(where: { $0.id == .moveColumnRight })?.shortcut.displayText, "Ctrl+Shift+Command+Right")
        XCTAssertEqual(commands.first(where: { $0.id == .transferColumnUp })?.shortcut.displayText, "Ctrl+Shift+Command+Up")
        XCTAssertEqual(commands.first(where: { $0.id == .transferColumnDown })?.shortcut.displayText, "Ctrl+Shift+Command+Down")
        XCTAssertEqual(commands.first(where: { $0.id == .showShortcutOverlay })?.shortcut.displayText, "Ctrl+Shift+/")
    }

    func testShortcutOverlayRowsAreGeneratedFromCommandRegistry() {
        let rows = ShortcutOverlayModel(registry: .v1).rows

        XCTAssertTrue(rows.contains(.init(commandTitle: "Focus Left", shortcutText: "Ctrl+Shift+Left")))
        XCTAssertTrue(rows.contains(.init(commandTitle: "Transfer Column Down", shortcutText: "Ctrl+Shift+Command+Down")))
        XCTAssertTrue(rows.contains(.init(commandTitle: "Shortcut Overlay", shortcutText: "Ctrl+Shift+/")))
    }

    func testPersistenceSnapshotRestoresNonEmptyWorkspacesAndRecreatesBottomEmptyWorkspace() throws {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))
        stack.createWindow(kind: .terminal)
        let terminalWindowID = stack.workspaces[0].columns[0].windows[0].id
        stack.workspaces[0].columns[0].windows[0].restoreMetadata.terminalCurrentDirectory = URL(filePath: "/Users/tester/project/Sources")
        stack.createWindow(kind: .browser)
        let browserWindowID = stack.workspaces[0].columns[1].windows[0].id
        stack.workspaces[0].columns[1].windows[0].restoreMetadata.browserURL = URL(string: "https://example.com")
        stack.rotateFocusedColumnWidth()
        stack.moveFocus(.left, visibleColumnCount: 1)

        let data = try JSONEncoder().encode(WorkspaceStackSnapshot(stack: stack))
        let snapshot = try JSONDecoder().decode(WorkspaceStackSnapshot.self, from: data)
        let restored = WorkspaceStack.restore(from: snapshot, defaultWorkspaceRoot: URL(filePath: "/Users/tester"))

        XCTAssertEqual(snapshot.workspaces.count, 1)
        XCTAssertEqual(restored.workspaces.count, 2)
        XCTAssertFalse(restored.workspaces[0].isEmptyWorkspace)
        XCTAssertTrue(restored.workspaces[1].isEmptyWorkspace)
        XCTAssertEqual(restored.workspaces[0].workspaceRoot.path(), "/Users/tester/project")
        XCTAssertEqual(restored.workspaces[0].focusedWindowID, terminalWindowID)
        XCTAssertEqual(restored.workspaces[0].horizontalScrollPosition, 0)
        XCTAssertEqual(restored.workspaces[0].columns.map(\.widthMode), [.half, .twoThirds])
        XCTAssertEqual(restored.workspaces[0].columns[0].windows[0].id, terminalWindowID)
        XCTAssertEqual(restored.workspaces[0].columns[0].windows[0].kind, .terminal)
        XCTAssertEqual(restored.workspaces[0].columns[0].windows[0].restoreMetadata.terminalCurrentDirectory?.path(), "/Users/tester/project/Sources")
        XCTAssertEqual(restored.workspaces[0].columns[1].windows[0].id, browserWindowID)
        XCTAssertEqual(restored.workspaces[0].columns[1].windows[0].kind, .browser)
        XCTAssertEqual(restored.workspaces[0].columns[1].windows[0].restoreMetadata.browserURL?.absoluteString, "https://example.com")
    }

    func testBrowserWindowDefaultsToAboutBlankAndPersistsCommittedURLForRestore() throws {
        var stack = WorkspaceStack.initial(workspaceRoot: URL(filePath: "/Users/tester/project"))

        stack.createWindow(kind: .browser)
        let browserWindowID = stack.workspaces[0].columns[0].windows[0].id

        XCTAssertEqual(stack.workspaces[0].columns[0].windows[0].restoreMetadata.browserURL?.absoluteString, "about:blank")

        stack.commitBrowserURL(URL(string: "https://example.com/docs")!, for: browserWindowID)

        let data = try JSONEncoder().encode(WorkspaceStackSnapshot(stack: stack))
        let snapshot = try JSONDecoder().decode(WorkspaceStackSnapshot.self, from: data)
        let restored = WorkspaceStack.restore(from: snapshot, defaultWorkspaceRoot: URL(filePath: "/Users/tester"))

        XCTAssertEqual(restored.workspaces[0].columns[0].windows[0].kind, .browser)
        XCTAssertEqual(restored.workspaces[0].columns[0].windows[0].restoreMetadata.browserURL?.absoluteString, "https://example.com/docs")
    }

    func testBrowserAddressNormalizerPreservesExplicitSchemesAndAboutBlank() {
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "about:blank")?.absoluteString,
            "about:blank"
        )
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "http://localhost:3000")?.absoluteString,
            "http://localhost:3000"
        )
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "https://example.com/docs")?.absoluteString,
            "https://example.com/docs"
        )
    }

    func testBrowserAddressNormalizerDefaultsLocalAddressesToHTTP() {
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "localhost:3000")?.absoluteString,
            "http://localhost:3000"
        )
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "127.0.0.1:5173/path")?.absoluteString,
            "http://127.0.0.1:5173/path"
        )
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "[::1]:8080")?.absoluteString,
            "http://[::1]:8080"
        )
    }

    func testBrowserAddressNormalizerDefaultsRemoteAddressesToHTTPS() {
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "example.com:8080")?.absoluteString,
            "https://example.com:8080"
        )
        XCTAssertEqual(
            BrowserAddressNormalizer.normalizedURL(from: "example.com/docs")?.absoluteString,
            "https://example.com/docs"
        )
    }
}
