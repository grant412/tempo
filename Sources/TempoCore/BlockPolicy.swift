import Foundation

public enum BlockAction: Equatable, Sendable {
    case allow
    case blockAdult
    case blockDistraction(site: String, until: Date)
    /// Load this URL instead (SafeSearch).
    case rewrite(String)
}

/// Decides what happens to one tab (site blocking spec 3.1): adult, then Distraction inside the
/// window, then SafeSearch.
public struct BlockPolicy: Sendable {
    public let adult: AdultSites
    public let resolver: RuleResolver
    /// The Distraction window running now, nil outside it.
    public let window: DateInterval?

    public init(adult: AdultSites, resolver: RuleResolver, window: DateInterval?) {
        self.adult = adult
        self.resolver = resolver
        self.window = window
    }

    /// Work pages on a Distraction site, as host and path prefix: never blocked by the window.
    static let workPages: [(host: String, path: String)] = [
        ("facebook.com", "/ads/library"),
    ]

    public func action(for url: String) -> BlockAction {
        guard let host = Domain.normalize(url) else { return .allow }
        if adult.contains(host: host) { return .blockAdult }
        if let window, resolver.category(for: ItemKey(kind: .domain, key: host)) == .distraction,
           !Self.isWorkPage(host: host, url: url) {
            return .blockDistraction(site: host, until: window.end)
        }
        if let rewritten = SafeSearch.enforced(url) { return .rewrite(rewritten) }
        return .allow
    }

    static func isWorkPage(host: String, url: String) -> Bool {
        guard let path = URL(string: url)?.path else { return false }
        return workPages.contains { page in
            (host == page.host || host.hasSuffix("." + page.host))
                && (path == page.path || path.hasPrefix(page.path + "/"))
        }
    }
}
