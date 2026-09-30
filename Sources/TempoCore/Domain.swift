import Foundation

public enum Domain {
    /// Lowercased host without a leading "www." or a trailing ".". Keeps the port only for local hosts.
    /// Returns nil for anything that is not http or https.
    public static func normalize(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var host = url.host?.lowercased(), !host.isEmpty
        else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if host.hasSuffix(".") { host.removeLast() }
        if isLocal(host), let port = url.port { return "\(host):\(port)" }
        return host
    }

    /// Exact host first, then each parent down to two labels.
    public static func candidates(for host: String) -> [String] {
        if host.contains(":") || isIPv4(host) { return [host] }
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return [host] }
        return (0...(labels.count - 2)).map { labels[$0...].joined(separator: ".") }
    }

    static func isLocal(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".localhost") || host.hasSuffix(".test")
    }

    static func isIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0) != nil }
    }
}
