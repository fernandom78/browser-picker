import XCTest
@testable import BrowserPicker

/// Covers `ChromiumLocalStateParser`, the JSON parsing shared by every
/// Chromium-based browser's profile discovery (built-in and custom alike).
/// Uses a temporary file on disk rather than mocking, since the parser's
/// only real job is reading + interpreting a real "Local State" file shape.
final class ChromiumLocalStateParserTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
    }

    private func write(_ contents: String, named name: String = "Local State") -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// A real-shaped "Local State" file (matching what Chrome/Edge/Brave/
    /// Opera/Arc all actually write) must parse into (key, name) pairs
    /// sorted by key, with each profile's display name taken from its
    /// "name" field.
    func test_parsesValidInfoCache_sortedByKey_withDisplayNames() {
        let url = write("""
        {
            "profile": {
                "info_cache": {
                    "Profile 1": { "name": "Work" },
                    "Default": { "name": "Personal" }
                }
            }
        }
        """)

        let entries = ChromiumLocalStateParser.parseProfiles(at: url)

        XCTAssertEqual(entries?.count, 2)
        XCTAssertEqual(entries?[0].key, "Default")
        XCTAssertEqual(entries?[0].name, "Personal")
        XCTAssertEqual(entries?[1].key, "Profile 1")
        XCTAssertEqual(entries?[1].name, "Work")
    }

    /// A profile entry with no "name" field (seen in the wild — e.g. Opera's
    /// single default profile on a fresh install) must fall back to using
    /// its dictionary key as the display name, rather than crashing or
    /// producing a blank name.
    func test_profileEntryWithoutNameField_fallsBackToKeyAsDisplayName() {
        let url = write("""
        {
            "profile": {
                "info_cache": {
                    "Default": {}
                }
            }
        }
        """)

        let entries = ChromiumLocalStateParser.parseProfiles(at: url)

        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?[0].name, "Default")
    }

    /// A file that exists but doesn't have the expected "profile.info_cache"
    /// shape (e.g. some unrelated JSON) must return nil, not throw or crash
    /// — callers fall back to a single "Default" profile in that case.
    func test_wrongShapeJSON_returnsNil() {
        let url = write("""
        { "unrelated": "data" }
        """)

        XCTAssertNil(ChromiumLocalStateParser.parseProfiles(at: url))
    }

    /// A path that doesn't exist at all must also return nil rather than
    /// throwing — this is the common case for a browser that's installed
    /// but has never been launched yet, so it has no "Local State" file.
    func test_missingFile_returnsNil() {
        let missingURL = tempDirectory.appendingPathComponent("does-not-exist")
        XCTAssertNil(ChromiumLocalStateParser.parseProfiles(at: missingURL))
    }
}
