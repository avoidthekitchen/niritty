import Foundation
import XCTest

final class DocumentationTests: XCTestCase {
    func testREADMEIdentifiesImplementedV1Behavior() throws {
        let readme = try repositoryText(at: "README.md")

        XCTAssertTrue(readme.contains("## Implemented V1"))
        XCTAssertTrue(readme.contains("Niritty v1 supports:"))
        XCTAssertFalse(readme.contains("The project is currently in planning."))
    }

    func testREADMEListsDeferredScopeBeyondV1() throws {
        let readme = try repositoryText(at: "README.md")

        XCTAssertTrue(readme.contains("## Deferred Beyond V1"))
        XCTAssertTrue(readme.contains("- Command Palette"))
        XCTAssertTrue(readme.contains("- Niri-style Overview"))
        XCTAssertTrue(readme.contains("- terminal process resurrection"))
        XCTAssertTrue(readme.contains("- multiple native macOS app windows"))
    }

    func testPRDRecordsImplementationClarifications() throws {
        let prd = try repositoryText(at: "docs/prd-v1.md")

        XCTAssertTrue(prd.contains("## Implementation Status and Clarifications"))
        XCTAssertTrue(prd.contains("The v1 implementation slices are complete."))
        XCTAssertTrue(prd.contains("pinned `Vendor/ghostty` submodule"))
        XCTAssertTrue(prd.contains("Apple Silicon"))
        XCTAssertTrue(prd.contains("embedded terminal or browser content owns keyboard focus"))
    }

    func testPRDKeepsNiriAsTheSpatialAmbiguityReference() throws {
        let prd = try repositoryText(at: "docs/prd-v1.md")

        XCTAssertTrue(prd.contains("[Niri](https://github.com/niri-wm/niri)"))
        XCTAssertTrue(prd.contains("reference for resolving ambiguity in the spatial model"))
        XCTAssertTrue(prd.contains("unless Niritty has an explicit conflicting decision in this PRD"))
    }

    func testPRDLimitsCMUXToNativeTerminalEmbeddingPriorArt() throws {
        let prd = try repositoryText(at: "docs/prd-v1.md")

        XCTAssertTrue(prd.contains("[CMUX](https://github.com/manaflow-ai/cmux)"))
        XCTAssertTrue(prd.contains("native macOS app that embeds Ghostty-style terminal surfaces"))
        XCTAssertTrue(prd.contains("integration prior art, not as a product-scope template"))
        XCTAssertTrue(prd.contains("should not inherit CMUX's AI-agent or mobile-sync product scope"))
    }

    func testContextRemainsGlossaryOnly() throws {
        let context = try repositoryText(at: "CONTEXT.md")
        let headings = context
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.hasPrefix("#") }

        XCTAssertEqual(headings, ["# Niritty", "## Language"])
        XCTAssertTrue(context.contains("**Workspace**:"))
        XCTAssertTrue(context.contains("**Column**:"))
        XCTAssertTrue(context.contains("**Window**:"))
        XCTAssertFalse(context.contains("## Implementation"))
        XCTAssertFalse(context.contains("## Architecture"))
        XCTAssertFalse(context.contains("## Milestones"))
    }

    private func repositoryText(at path: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appending(path: path),
            encoding: .utf8
        )
    }
}
