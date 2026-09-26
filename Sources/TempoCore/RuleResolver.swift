import Foundation

public struct RuleResolver: Sendable {
    private let byKey: [ItemKey: Rule]

    public init(rules: [Rule]) {
        byKey = Dictionary(rules.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The rule that decides this key's category, skipping tombstones.
    public func matchedRule(for key: ItemKey) -> Rule? {
        switch key.kind {
        case .app:
            if let r = byKey[key], r.category != nil { return r }
            return nil
        case .domain:
            for host in Domain.candidates(for: key.key) {
                if let r = byKey[ItemKey(kind: .domain, key: host)], r.category != nil { return r }
            }
            return nil
        }
    }

    public func category(for key: ItemKey) -> CategoryID {
        matchedRule(for: key)?.category ?? .uncategorized
    }

    /// True when Claude should not be asked about this key.
    public func isKnown(_ key: ItemKey) -> Bool {
        byKey[key] != nil || matchedRule(for: key) != nil
    }
}
