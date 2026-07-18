import XCTest
@testable import BrowserPicker

/// Covers `RuleMatcher.matches`, the predicate every routing rule is built
/// on. These are pure string/URL checks with no filesystem or app state
/// involved, so they're cheap to run on every change.
final class RuleMatcherTests: XCTestCase {

    /// "URL contains" should match anywhere in the full URL string,
    /// case-insensitively, not just in the host.
    func test_urlContains_matchesSubstringAnywhereInURL_caseInsensitive() {
        let matcher = RuleMatcher(kind: .urlContains, value: "R2O")
        XCTAssertTrue(matcher.matches(url: URL(string: "https://go.example.com/r2o/ticket/123")!, sourceApp: nil))
        XCTAssertFalse(matcher.matches(url: URL(string: "https://example.com/other")!, sourceApp: nil))
    }

    /// "Host equals" must match the host exactly — a subdomain or a
    /// completely different host should not match.
    func test_hostEquals_matchesExactHostOnly() {
        let matcher = RuleMatcher(kind: .hostEquals, value: "github.com")
        XCTAssertTrue(matcher.matches(url: URL(string: "https://github.com/mertizci/browser-picker")!, sourceApp: nil))
        XCTAssertFalse(matcher.matches(url: URL(string: "https://gist.github.com/foo")!, sourceApp: nil))
        XCTAssertFalse(matcher.matches(url: URL(string: "https://notgithub.com")!, sourceApp: nil))
    }

    /// "Host suffix" should match a subdomain of the configured domain...
    func test_hostSuffix_matchesSubdomain() {
        let matcher = RuleMatcher(kind: .hostSuffix, value: "company.com")
        XCTAssertTrue(matcher.matches(url: URL(string: "https://mail.company.com/inbox")!, sourceApp: nil))
    }

    /// ...and also the bare domain itself (no subdomain), which a naive
    /// `hasSuffix` check alone could miss depending on how the leading dot
    /// is handled.
    func test_hostSuffix_alsoMatchesBareDomain() {
        let matcher = RuleMatcher(kind: .hostSuffix, value: ".company.com")
        XCTAssertTrue(matcher.matches(url: URL(string: "https://company.com")!, sourceApp: nil))
    }

    /// A suffix match must not fire on an unrelated host that merely ends
    /// with the same trailing characters (e.g. "evilcompany.com" should not
    /// match a rule for "company.com").
    func test_hostSuffix_doesNotMatchUnrelatedHostWithSameTrailingCharacters() {
        let matcher = RuleMatcher(kind: .hostSuffix, value: "company.com")
        XCTAssertFalse(matcher.matches(url: URL(string: "https://evilcompany.com")!, sourceApp: nil))
    }
}
