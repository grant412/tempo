import Foundation

/// While a Distraction window runs, refuses rule changes that would take a domain out of
/// Distraction (site blocking spec 3.4). Only consulted while a window runs.
public enum RuleLock {
    /// `newCategory` nil means the rule is being deleted. App rules are never locked.
    public static func allows(_ key: ItemKey, newCategory: CategoryID?, rules: [Rule]) -> Bool {
        guard key.kind == .domain else { return true }
        guard RuleResolver(rules: rules).category(for: key) == .distraction else { return true }
        var after = rules.filter { $0.key != key }
        after.append(Rule(key: key, category: newCategory, source: .user, updatedAt: Date()))
        return RuleResolver(rules: after).category(for: key) == .distraction
    }
}
