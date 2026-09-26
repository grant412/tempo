import Foundation

public struct ClassifyItem: Equatable, Sendable {
    public let key: ItemKey
    public let appName: String
    public let sampleTitle: String?
    public init(key: ItemKey, appName: String, sampleTitle: String?) {
        self.key = key
        self.appName = appName
        self.sampleTitle = sampleTitle
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClassifierError.badResponse }
        return (data, http)
    }
}

public enum ClassifierError: Error, Equatable {
    case unauthorized
    case http(Int)
    case badResponse
    case refused
}

public struct ClaudeClassifier: Sendable {
    public static let model = "claude-haiku-4-5"
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public let apiKey: String
    public let transport: HTTPTransport

    public init(apiKey: String, transport: HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.transport = transport
    }

    public func makeRequest(items: [ClassifyItem]) throws -> URLRequest {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: Self.body(items: items), options: [.sortedKeys])
        return req
    }

    public func classify(_ items: [ClassifyItem]) async throws -> [ItemKey: CategoryID] {
        guard !items.isEmpty else { return [:] }
        let (data, response) = try await transport.send(try makeRequest(items: items))
        switch response.statusCode {
        case 200: return try Self.parse(data: data, items: items)
        case 401: throw ClassifierError.unauthorized
        default: throw ClassifierError.http(response.statusCode)
        }
    }

    static let systemPrompt: String =
        "You sort Mac apps and websites into categories for a personal time tracker. Categories:\n"
        + CategoryID.assignable.map { "- \($0.rawValue): \($0.promptDescription)" }.joined(separator: "\n")
        + "\nPick the single best category for each item. If unsure, pick what a typical knowledge worker most often uses it for."

    /// Window and tab titles can hold URLs, paths, or query strings. Any title that looks like one is never sent.
    static func safeTitle(_ title: String?) -> String? {
        guard let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if ["://", "~/", "?", "="].contains(where: trimmed.contains) { return nil }
        // A slash followed by a non-space character: "a/b", "/Users/...", and "grant@Mac: /etc".
        if trimmed.range(of: #"/\S"#, options: .regularExpression) != nil { return nil }
        return String(trimmed.prefix(120))
    }

    static func body(items: [ClassifyItem]) -> [String: Any] {
        let list: [[String: Any]] = items.enumerated().map { index, item in
            var o: [String: Any] = [
                "id": String(index),
                "kind": item.key.kind == .domain ? "website" : "app",
                "name": item.key.kind == .domain ? item.key.key : item.appName,
                "app": item.appName,
            ]
            if let title = safeTitle(item.sampleTitle) { o["title"] = title }
            return o
        }
        let listData = (try? JSONSerialization.data(withJSONObject: list, options: [.sortedKeys])) ?? Data("[]".utf8)
        let listJSON = String(data: listData, encoding: .utf8) ?? "[]"
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "results": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string"],
                            "category": ["type": "string", "enum": CategoryID.assignable.map(\.rawValue)],
                        ],
                        "required": ["id", "category"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["results"],
            "additionalProperties": false,
        ]
        return [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [["role": "user", "content": "Sort each item into one category.\n" + listJSON]],
            "output_config": ["format": ["type": "json_schema", "schema": schema]],
        ]
    }

    public static func parse(data: Data, items: [ClassifyItem]) throws -> [ItemKey: CategoryID] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClassifierError.badResponse
        }
        if (root["stop_reason"] as? String) == "refusal" { throw ClassifierError.refused }
        guard let content = root["content"] as? [[String: Any]],
              let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              let inner = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let results = inner["results"] as? [[String: Any]]
        else { throw ClassifierError.badResponse }
        var out: [ItemKey: CategoryID] = [:]
        for r in results {
            guard let index = (r["id"] as? String).flatMap(Int.init), items.indices.contains(index),
                  let cat = (r["category"] as? String).flatMap(CategoryID.init(rawValue:)),
                  cat != .uncategorized else { continue }
            out[items[index].key] = cat
        }
        return out
    }
}
