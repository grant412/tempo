import Foundation

/// Forces strict SafeSearch on Google, Bing, and DuckDuckGo searches (site blocking spec 5.1).
public enum SafeSearch {
    /// The URL with the engine's strict parameter set, or nil when it is not a search on these
    /// engines or already has it. Every other parameter keeps its exact encoding.
    public static func enforced(_ urlString: String) -> String? {
        guard var parts = URLComponents(string: urlString),
              let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var host = parts.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if host.hasSuffix(".") { host.removeLast() }
        var items = parts.percentEncodedQueryItems ?? []
        let param: (name: String, value: String)
        if isGoogle(host), parts.path == "/search" {
            param = ("safe", "active")
        } else if host == "bing.com" || host.hasSuffix(".bing.com"),
                  ["/search", "/images/search", "/videos/search"].contains(parts.path) {
            param = ("adlt", "strict")
        } else if ["duckduckgo.com", "html.duckduckgo.com", "lite.duckduckgo.com"].contains(host),
                  items.contains(where: { $0.name == "q" && !($0.value ?? "").isEmpty }) {
            param = ("kp", "1")
        } else {
            return nil
        }
        let existing = items.filter { $0.name == param.name }
        if existing.count == 1, existing[0].value == param.value { return nil }
        items.removeAll { $0.name == param.name }
        items.append(URLQueryItem(name: param.name, value: param.value))
        parts.percentEncodedQueryItems = items
        return parts.string
    }

    /// google.<tld>, google.co.<cc>, or google.com.<cc>.
    static func isGoogle(_ host: String) -> Bool {
        let labels = host.split(separator: ".")
        guard labels.first == "google" else { return false }
        switch labels.count {
        case 2: return true
        case 3: return labels[1] == "co" || labels[1] == "com"
        default: return false
        }
    }
}
