import Foundation

/// Adult sites: the bundled OISD list, a few words, and the list's one-label entries
/// (site blocking spec 5.1).
public struct AdultSites: Sendable {
    public static let words = ["porn", "xxx", "hentai"]

    private let domains: Set<String>
    private let topLevel: Set<String>

    public var count: Int { domains.count + topLevel.count }

    /// Parses OISD "domains (wildcards)" text: one domain per line, `#` comments. Each entry also
    /// covers its subdomains. A one-label entry (xxx, porn) blocks that whole top-level domain.
    public init(listText: String) {
        var domains = Set<String>()
        var topLevel = Set<String>()
        for raw in listText.split(whereSeparator: \.isNewline) {
            var entry = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if entry.isEmpty || entry.hasPrefix("#") { continue }
            if entry.hasPrefix("*.") { entry.removeFirst(2) }
            if entry.hasPrefix("www.") { entry.removeFirst(4) }
            if entry.isEmpty { continue }
            if entry.contains(".") { domains.insert(entry) } else { topLevel.insert(entry) }
        }
        self.domains = domains
        self.topLevel = topLevel
    }

    /// `host` as `Domain.normalize` returns it. Hosts with a port and IPv4 addresses never match.
    public func contains(host: String) -> Bool {
        let host = host.lowercased()
        if host.contains(":") || Domain.isIPv4(host) { return false }
        if Self.words.contains(where: { host.contains($0) }) { return true }
        if let last = host.split(separator: ".").last, topLevel.contains(String(last)) { return true }
        return Domain.candidates(for: host).contains { domains.contains($0) }
    }
}
