import XCTest
@testable import BrowserPicker

/// Covers `RuleEngine`, which decides where a link goes: the first enabled,
/// priority-ordered rule that matches, or the default target if none do.
final class RuleEngineTests: XCTestCase {
    private let engine = RuleEngine()

    private func rule(
        priority: Int,
        value: String,
        enabled: Bool = true,
        browser: BrowserIdentity = .builtIn(.chrome),
        profileId: String = "Default",
        openPrivately: Bool = false
    ) -> RoutingRule {
        RoutingRule(
            name: "Test rule \(priority)",
            enabled: enabled,
            priority: priority,
            matcher: RuleMatcher(kind: .urlContains, value: value),
            target: RouteTarget(browser: browser, profileId: profileId),
            openPrivately: openPrivately
        )
    }

    private var defaultSettings: AppSettings {
        AppSettings(
            fallbackMode: .silent,
            defaultTarget: RouteTarget(browser: .builtIn(.safari), profileId: "DefaultProfile"),
            rules: [],
            customBrowsers: []
        )
    }

    /// When two enabled rules both match, the one with the lower `priority`
    /// value must win, regardless of the order they appear in the array —
    /// `matchingRule` sorts before searching, it doesn't rely on array order.
    func test_lowerPriorityRuleWinsWhenMultipleRulesMatch() {
        var settings = defaultSettings
        settings.rules = [
            rule(priority: 5, value: "example", browser: .builtIn(.firefox)),
            rule(priority: 1, value: "example", browser: .builtIn(.chrome))
        ]

        let (target, _) = engine.resolve(
            for: RoutingContext(url: URL(string: "https://example.com")!, sourceApp: nil),
            settings: settings
        )

        XCTAssertEqual(target.browser, .builtIn(.chrome))
    }

    /// A disabled rule must never be selected, even if it would otherwise be
    /// the highest-priority match.
    func test_disabledRuleIsSkippedEvenIfHighestPriority() {
        var settings = defaultSettings
        settings.rules = [
            rule(priority: 0, value: "example", enabled: false, browser: .builtIn(.firefox)),
            rule(priority: 1, value: "example", browser: .builtIn(.chrome))
        ]

        let (target, _) = engine.resolve(
            for: RoutingContext(url: URL(string: "https://example.com")!, sourceApp: nil),
            settings: settings
        )

        XCTAssertEqual(target.browser, .builtIn(.chrome))
    }

    /// With no matching rule at all, resolution must fall back to
    /// `settings.defaultTarget`, and never open privately (private mode is
    /// only ever an explicit choice — a rule's own flag, or the manual
    /// picker's own toggle, which doesn't go through this code path).
    func test_noMatchingRule_fallsBackToDefaultTarget_neverPrivate() {
        var settings = defaultSettings
        settings.rules = [rule(priority: 0, value: "nomatch")]

        let (target, openPrivately) = engine.resolve(
            for: RoutingContext(url: URL(string: "https://example.com")!, sourceApp: nil),
            settings: settings
        )

        XCTAssertEqual(target, settings.defaultTarget)
        XCTAssertFalse(openPrivately)
    }

    /// A matched rule's `openPrivately` flag must be surfaced exactly as
    /// saved — this is the field that drives whether the launcher is told
    /// to open a private/incognito window.
    func test_matchedRule_surfacesItsOwnOpenPrivatelyFlag() {
        var settings = defaultSettings
        settings.rules = [rule(priority: 0, value: "example", openPrivately: true)]

        let (_, openPrivately) = engine.resolve(
            for: RoutingContext(url: URL(string: "https://example.com")!, sourceApp: nil),
            settings: settings
        )

        XCTAssertTrue(openPrivately)
    }
}
