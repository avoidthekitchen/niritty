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
        XCTAssertTrue(script.contains("\"$ROOT_DIR/script/ensure_ghosttykit.sh\"\nswift build"))
        XCTAssertTrue(script.contains("cp -R \"$GHOSTTY_RESOURCES\" \"$APP_RESOURCES/ghostty\""))
        XCTAssertTrue(script.contains("Run script/ensure_ghosttykit.sh before packaging Niritty."))
    }

    private var packageRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
