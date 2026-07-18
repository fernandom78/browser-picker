import XCTest
@testable import BrowserPicker

/// Covers the JSON encoding/decoding contracts that matter most for a
/// settings file that persists indefinitely across app upgrades
/// (`~/Library/Application Support/BrowserPicker/config.json`): a `BrowserIdentity`
/// must stay wire-compatible with the old `BrowserKind`-typed field it
/// replaced, and newly-added fields (`RoutingRule.openPrivately`,
/// `AppSettings.customBrowsers`) must not break decoding of configs saved
/// before those fields existed.
final class CodableCompatibilityTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - BrowserIdentity

    /// A `.builtIn` identity must encode as exactly its raw value string
    /// (e.g. "chrome"), with no wrapper object — this is what makes it
    /// wire-compatible with the original `BrowserKind`-typed field.
    func test_builtInIdentity_encodesAsPlainRawValueString() throws {
        let data = try encoder.encode(BrowserIdentity.builtIn(.chrome))
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"chrome\"")
    }

    /// A `.custom` identity must encode with the "custom:" prefix followed
    /// by its UUID, a format that can never collide with a real
    /// `BrowserKind` raw value.
    func test_customIdentity_encodesWithCustomPrefix() throws {
        let id = UUID()
        let data = try encoder.encode(BrowserIdentity.custom(id))
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"custom:\(id.uuidString)\"")
    }

    /// A plain browser-name string, exactly as an old config.json (saved
    /// before `BrowserIdentity` existed) would contain, must decode as the
    /// matching `.builtIn` case with zero migration step.
    func test_plainOldStyleBrowserString_decodesAsBuiltIn() throws {
        let json = "\"safari\"".data(using: .utf8)!
        let identity = try decoder.decode(BrowserIdentity.self, from: json)
        XCTAssertEqual(identity, .builtIn(.safari))
    }

    /// A "custom:<uuid>" string round-trips back to the same `.custom` id.
    func test_customPrefixedString_decodesBackToSameUUID() throws {
        let id = UUID()
        let json = "\"custom:\(id.uuidString)\"".data(using: .utf8)!
        let identity = try decoder.decode(BrowserIdentity.self, from: json)
        XCTAssertEqual(identity, .custom(id))
    }

    /// A string that's neither a known `BrowserKind` raw value nor a valid
    /// "custom:<uuid>" must fail to decode loudly, rather than silently
    /// mapping to some default browser.
    func test_unknownBrowserString_throwsRatherThanSilentlyDefaulting() {
        let json = "\"some-made-up-browser\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(BrowserIdentity.self, from: json))
    }

    // MARK: - RoutingRule.openPrivately backward compatibility

    /// A rule JSON object saved by a build *before* `openPrivately` existed
    /// (no such key at all) must still decode successfully, defaulting
    /// `openPrivately` to false — this is what keeps an existing user's
    /// saved rules loading after upgrading rather than corrupting their
    /// whole config.json.
    func test_routingRule_missingOpenPrivatelyKey_decodesAsFalse() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Old rule",
            "enabled": true,
            "priority": 0,
            "matcher": { "kind": "urlContains", "value": "example" },
            "target": { "browser": "chrome", "profileId": "Default" }
        }
        """.data(using: .utf8)!

        let rule = try decoder.decode(RoutingRule.self, from: json)
        XCTAssertFalse(rule.openPrivately)
    }

    /// When `openPrivately` *is* present, it must decode to its actual
    /// value rather than always defaulting to false.
    func test_routingRule_presentOpenPrivatelyKey_decodesItsValue() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "New rule",
            "enabled": true,
            "priority": 0,
            "matcher": { "kind": "urlContains", "value": "example" },
            "target": { "browser": "chrome", "profileId": "Default" },
            "openPrivately": true
        }
        """.data(using: .utf8)!

        let rule = try decoder.decode(RoutingRule.self, from: json)
        XCTAssertTrue(rule.openPrivately)
    }

    // MARK: - AppSettings.customBrowsers backward compatibility

    /// A config.json saved before `customBrowsers` existed (no such key)
    /// must still decode successfully, defaulting to an empty array —
    /// otherwise every existing user's settings file would fail to load
    /// entirely after upgrading to a build with custom-browser support.
    func test_appSettings_missingCustomBrowsersKey_decodesAsEmptyArray() throws {
        let json = """
        {
            "fallbackMode": "picker",
            "defaultTarget": { "browser": "safari", "profileId": "DefaultProfile" },
            "rules": []
        }
        """.data(using: .utf8)!

        let settings = try decoder.decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.customBrowsers, [])
    }

    /// A full round-trip (encode then decode) of `AppSettings` with a
    /// non-empty `customBrowsers` list must preserve every field exactly.
    func test_appSettings_roundTripsCustomBrowsersCorrectly() throws {
        let custom = CustomBrowser(displayName: "Test Fork", appPath: "/Applications/TestFork.app")
        let original = AppSettings(
            fallbackMode: .silent,
            defaultTarget: RouteTarget(browser: .custom(custom.id), profileId: "Default"),
            rules: [],
            customBrowsers: [custom]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.customBrowsers, [custom])
        XCTAssertEqual(decoded.defaultTarget.browser, .custom(custom.id))
    }
}
