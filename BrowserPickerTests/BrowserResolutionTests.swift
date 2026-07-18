import XCTest
@testable import BrowserPicker

/// Covers `BrowserKind.chromiumPrivateFlag` and `BrowserIdentity.resolved(customBrowsers:)`
/// — the exact area where a real bug shipped during development (Edge silently
/// ignoring "--incognito" because it actually needs "--inprivate"). These
/// tests exist specifically to catch that class of regression automatically.
final class BrowserResolutionTests: XCTestCase {

    /// Edge is the one built-in browser confirmed (against a real install)
    /// to use a different private-mode flag than the rest — it rebrands the
    /// feature "InPrivate". This is the regression test for that exact bug.
    func test_edge_usesInPrivateFlag_notIncognito() {
        XCTAssertEqual(BrowserKind.edge.chromiumPrivateFlag, "--inprivate")
    }

    /// Every other Chromium-engine built-in browser is confirmed to accept
    /// the standard "--incognito" flag directly.
    func test_otherChromiumBrowsers_useIncognitoFlag() {
        for kind: BrowserKind in [.chrome, .brave, .vivaldi, .opera, .arc] {
            XCTAssertEqual(kind.chromiumPrivateFlag, "--incognito", "\(kind.rawValue) should use --incognito")
        }
    }

    /// Resolving a `.builtIn` identity must carry over that `BrowserKind`'s
    /// own engine, display name, and private-mode flag — not some generic
    /// default — so a rule targeting a built-in browser launches correctly.
    func test_resolvedBuiltIn_carriesOverKindsOwnProperties() {
        let resolved = BrowserIdentity.builtIn(.edge).resolved(customBrowsers: [])

        XCTAssertEqual(resolved?.engine, .chromium)
        XCTAssertEqual(resolved?.displayName, "Edge")
        XCTAssertEqual(resolved?.chromiumPrivateFlag, "--inprivate")
    }

    /// Resolving a `.custom` identity against a matching `CustomBrowser`
    /// must always report `.chromium` engine (customs are always assumed
    /// Chromium-based) and default to "--incognito", since we can't know a
    /// truly arbitrary fork's own branding for the feature.
    func test_resolvedCustom_isAlwaysChromiumEngine_defaultsToIncognito() {
        let custom = CustomBrowser(displayName: "Some Fork", appPath: "/Applications/SomeFork.app")
        let resolved = BrowserIdentity.custom(custom.id).resolved(customBrowsers: [custom])

        XCTAssertEqual(resolved?.engine, .chromium)
        XCTAssertEqual(resolved?.displayName, "Some Fork")
        XCTAssertEqual(resolved?.chromiumPrivateFlag, "--incognito")
    }

    /// Resolving a `.custom` identity whose `CustomBrowser` no longer exists
    /// in the current settings (e.g. removed after a rule referencing it was
    /// saved) must return nil rather than crashing or silently substituting
    /// some other browser.
    func test_resolvedCustom_missingFromList_returnsNil() {
        let resolved = BrowserIdentity.custom(UUID()).resolved(customBrowsers: [])
        XCTAssertNil(resolved)
    }
}
