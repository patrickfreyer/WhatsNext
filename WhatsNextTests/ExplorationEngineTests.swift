import XCTest
@testable import WhatsNext

final class ExplorationEngineTests: XCTestCase {

    private var engine: ExplorationEngine!

    override func setUp() {
        super.setUp()
        engine = ExplorationEngine.shared
    }

    // MARK: - fileMatchesPatterns Tests

    func testFileMatchesSwiftPattern() {
        XCTAssertTrue(engine.fileMatchesPatterns("ViewController.swift", patterns: ["*.swift"]))
    }

    func testFileDoesNotMatchSwiftPattern() {
        XCTAssertFalse(engine.fileMatchesPatterns("readme.md", patterns: ["*.swift"]))
    }

    func testFileMatchesMultiplePatterns() {
        let patterns = ["*.swift", "*.md", "*.json"]

        XCTAssertTrue(engine.fileMatchesPatterns("file.swift", patterns: patterns))
        XCTAssertTrue(engine.fileMatchesPatterns("README.md", patterns: patterns))
        XCTAssertTrue(engine.fileMatchesPatterns("config.json", patterns: patterns))
        XCTAssertFalse(engine.fileMatchesPatterns("image.png", patterns: patterns))
    }

    func testFileMatchesWildcardPattern() {
        XCTAssertTrue(engine.fileMatchesPatterns("anything.txt", patterns: ["*"]))
    }

    func testFileMatchesExactName() {
        XCTAssertTrue(engine.fileMatchesPatterns("Makefile", patterns: ["Makefile"]))
        XCTAssertFalse(engine.fileMatchesPatterns("Dockerfile", patterns: ["Makefile"]))
    }

    func testFileMatchesPrefixPattern() {
        XCTAssertTrue(engine.fileMatchesPatterns("test.swift", patterns: ["test.*"]))
        XCTAssertTrue(engine.fileMatchesPatterns("test.json", patterns: ["test.*"]))
        XCTAssertFalse(engine.fileMatchesPatterns("main.swift", patterns: ["test.*"]))
    }

    func testFileMatchesEmptyPatterns() {
        XCTAssertFalse(engine.fileMatchesPatterns("file.swift", patterns: []))
    }

    // MARK: - shouldExclude Tests

    func testShouldExcludeMatchingDirectoryComponent() {
        let path = URL(fileURLWithPath: "/Users/test/project/.git/config")
        XCTAssertTrue(engine.shouldExclude(path, excludePatterns: [".git"]))
    }

    func testShouldExcludeNodeModules() {
        let path = URL(fileURLWithPath: "/Users/test/project/node_modules/package/index.js")
        XCTAssertTrue(engine.shouldExclude(path, excludePatterns: ["node_modules"]))
    }

    func testShouldExcludeBuildDirectory() {
        let path = URL(fileURLWithPath: "/Users/test/project/build/output.o")
        XCTAssertTrue(engine.shouldExclude(path, excludePatterns: ["build"]))
    }

    func testShouldNotExcludeNonMatchingPath() {
        let path = URL(fileURLWithPath: "/Users/test/project/src/main.swift")
        XCTAssertFalse(engine.shouldExclude(path, excludePatterns: [".git", "node_modules", "build"]))
    }

    func testShouldExcludeByGlobPattern() {
        let path = URL(fileURLWithPath: "/Users/test/project/backup.swift")
        XCTAssertTrue(engine.shouldExclude(path, excludePatterns: ["*.swift"]))
    }

    func testShouldNotExcludeWithEmptyPatterns() {
        let path = URL(fileURLWithPath: "/Users/test/project/main.swift")
        XCTAssertFalse(engine.shouldExclude(path, excludePatterns: []))
    }

    func testShouldExcludeMultiplePatterns() {
        let excludePatterns = [".git", "node_modules", "build", ".build", "DerivedData", "Pods"]

        let gitPath = URL(fileURLWithPath: "/project/.git/HEAD")
        let derivedPath = URL(fileURLWithPath: "/project/DerivedData/Build/info.plist")
        let srcPath = URL(fileURLWithPath: "/project/Sources/main.swift")

        XCTAssertTrue(engine.shouldExclude(gitPath, excludePatterns: excludePatterns))
        XCTAssertTrue(engine.shouldExclude(derivedPath, excludePatterns: excludePatterns))
        XCTAssertFalse(engine.shouldExclude(srcPath, excludePatterns: excludePatterns))
    }
}
