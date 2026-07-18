import Foundation

struct RuleEngine {
    func matchingRule(for context: RoutingContext, in settings: AppSettings) -> RoutingRule? {
        settings.rules
            .filter(\.enabled)
            .sorted { $0.priority < $1.priority }
            .first { $0.matcher.matches(url: context.url, sourceApp: context.sourceApp) }
    }

    /// Resolves both the destination and whether it should open privately —
    /// a matched rule's own `openPrivately` flag always wins, since that's
    /// an explicit routing decision already made when the rule was saved.
    /// Falling back to the default target never opens privately; the manual
    /// picker (see `PickerPromptView`) has its own private-mode toggle and
    /// doesn't go through this path at all.
    func resolve(for context: RoutingContext, settings: AppSettings) -> (target: RouteTarget, openPrivately: Bool) {
        if let rule = matchingRule(for: context, in: settings) {
            return (rule.target, rule.openPrivately)
        }
        return (settings.defaultTarget, false)
    }
}
