import XCTest

final class GhosttyDependencyTests: XCTestCase {
    func testGhosttyKitArtifactContainsImportableHeadersAndStaticLibrary() {
        let root = packageRoot
        let fileManager = FileManager.default

        XCTAssertTrue(fileManager.fileExists(atPath: root.appending(path: ".gitmodules").path()))
        XCTAssertTrue(fileManager.fileExists(atPath: root.appending(path: "Vendor/ghostty/.git").path()))
        XCTAssertTrue(fileManager.fileExists(atPath: root.appending(path: "Vendor/ghostty/macos/GhosttyKit.xcframework/Info.plist").path()))
        XCTAssertTrue(fileManager.fileExists(atPath: root.appending(path: "Vendor/ghostty/macos/GhosttyKit.xcframework/macos-arm64/Headers/module.modulemap").path()))
        XCTAssertTrue(fileManager.fileExists(atPath: root.appending(path: "Vendor/ghostty/macos/GhosttyKit.xcframework/macos-arm64/Headers/ghostty.h").path()))
        XCTAssertTrue(fileManager.fileExists(atPath: root.appending(path: "Vendor/ghostty/macos/GhosttyKit.xcframework/macos-arm64/libghostty-internal-fat.a").path()))
    }

    func testGhosttyResourcesAndPackagingScriptStayInSync() throws {
        let root = packageRoot
        let fileManager = FileManager.default
        let resources = root.appending(path: "Vendor/ghostty/zig-out/share/ghostty")

        XCTAssertTrue(fileManager.fileExists(atPath: resources.appending(path: "shell-integration").path()))
        XCTAssertTrue(fileManager.fileExists(atPath: resources.appending(path: "themes").path()))

        let script = try String(contentsOf: root.appending(path: "script/build_and_run.sh"), encoding: .utf8)
        XCTAssertTrue(script.contains("GHOSTTY_RESOURCES="))
        XCTAssertTrue(script.contains("APP_RESOURCES="))
        XCTAssertTrue(script.contains("\"$ROOT_DIR/script/bootstrap.sh\"\nswift build"))
        XCTAssertTrue(script.contains("cp -R \"$GHOSTTY_RESOURCES\" \"$APP_RESOURCES/ghostty\""))
        XCTAssertTrue(script.contains("Run script/bootstrap.sh before packaging Niritty."))
    }

    func testBootstrapAndTestScriptsAreTheBlessedSwiftPMEntrypoints() throws {
        let root = packageRoot
        let bootstrap = try String(contentsOf: root.appending(path: "script/bootstrap.sh"), encoding: .utf8)
        let test = try String(contentsOf: root.appending(path: "script/test.sh"), encoding: .utf8)
        let integrationTest = try String(contentsOf: root.appending(path: "script/test_ghostty_integration.sh"), encoding: .utf8)

        XCTAssertTrue(bootstrap.contains("\"$ROOT_DIR/script/ensure_ghosttykit.sh\""))
        XCTAssertTrue(bootstrap.contains("git submodule update --init --recursive Vendor/ghostty"))
        XCTAssertTrue(bootstrap.contains("macos-arm64/Headers/ghostty.h"))
        XCTAssertTrue(bootstrap.contains("zig-out/share/ghostty"))
        XCTAssertTrue(test.contains("\"$ROOT_DIR/script/bootstrap.sh\""))
        XCTAssertTrue(test.contains("cd \"$ROOT_DIR\"\nswift test"))
        XCTAssertTrue(integrationTest.contains("script/test.sh"))
    }

    func testEnsureGhosttyKitTracksSubmoduleCommitAndRequiredOutputs() throws {
        let root = packageRoot
        let script = try String(contentsOf: root.appending(path: "script/ensure_ghosttykit.sh"), encoding: .utf8)

        XCTAssertTrue(script.contains("STAMP_FILE=\"$STAMP_DIR/ghosttykit-head.txt\""))
        XCTAssertTrue(script.contains("GHOSTTY_HEAD=\"$(git rev-parse HEAD)\""))
        XCTAssertTrue(script.contains("has_required_outputs"))
        XCTAssertTrue(script.contains("zig-out/share/ghostty"))
        XCTAssertTrue(script.contains("NIRITTY_GHOSTTYKIT_FORCE_REBUILD"))
        XCTAssertTrue(script.contains("printf '%s\\n' \"$GHOSTTY_HEAD\" >\"$STAMP_FILE\""))
    }

    private var packageRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
