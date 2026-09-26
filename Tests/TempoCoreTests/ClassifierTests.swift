import Foundation
import Testing
@testable import TempoCore

final class StubTransport: HTTPTransport, @unchecked Sendable {
    var lastRequest: URLRequest?
    let status: Int
    let body: Data
    init(status: Int, body: String) { self.status = status; self.body = Data(body.utf8) }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private let ytItem = ClassifyItem(key: ItemKey(kind: .domain, key: "youtube.com"), appName: "Google Chrome",
                                  sampleTitle: "Some video - YouTube")
private let appItem = ClassifyItem(key: ItemKey(kind: .app, key: "com.example.new"), appName: "NewApp", sampleTitle: nil)
private let okBody = """
{"content":[{"type":"text","text":"{\\"results\\":[{\\"id\\":\\"0\\",\\"category\\":\\"distraction\\"},{\\"id\\":\\"1\\",\\"category\\":\\"code\\"}]}"}],"stop_reason":"end_turn"}
"""

struct ClaudeClassifierTests {
    @Test func requestShape() throws {
        let c = ClaudeClassifier(apiKey: "test-key", transport: StubTransport(status: 200, body: okBody))
        let req = try c.makeRequest(items: [ytItem, appItem])
        #expect(req.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(req.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let json = try #require(try JSONSerialization.jsonObject(with: req.httpBody!) as? [String: Any])
        #expect(json["model"] as? String == "claude-haiku-4-5")
        #expect(json["thinking"] == nil)
        let format = (json["output_config"] as? [String: Any])?["format"] as? [String: Any]
        #expect(format?["type"] as? String == "json_schema")
        let raw = String(data: req.httpBody!, encoding: .utf8)!
        #expect(raw.contains("youtube.com"))
        #expect(!raw.contains("https:"))
        for id in CategoryID.assignable { #expect(raw.contains("\"\(id.rawValue)\"")) }
        #expect(!raw.contains("\"uncategorized\""))
    }

    @Test func parsesResults() async throws {
        let c = ClaudeClassifier(apiKey: "k", transport: StubTransport(status: 200, body: okBody))
        let out = try await c.classify([ytItem, appItem])
        #expect(out == [ytItem.key: .distraction, appItem.key: .code])
    }

    @Test func mapsErrors() async {
        let unauthorized = ClaudeClassifier(apiKey: "k", transport: StubTransport(status: 401, body: "{}"))
        await #expect(throws: ClassifierError.unauthorized) { try await unauthorized.classify([ytItem]) }
        let server = ClaudeClassifier(apiKey: "k", transport: StubTransport(status: 529, body: "{}"))
        await #expect(throws: ClassifierError.http(529)) { try await server.classify([ytItem]) }
        let refusal = ClaudeClassifier(apiKey: "k", transport: StubTransport(status: 200, body: #"{"content":[],"stop_reason":"refusal"}"#))
        await #expect(throws: ClassifierError.refused) { try await refusal.classify([ytItem]) }
    }
}

struct ClassifierQueueTests {
    private let now = Date(timeIntervalSince1970: 5_000_000)

    @Test func skipsKnownKeysAndDuplicates() throws {
        let store = try Store(path: ":memory:")
        let q = ClassifierQueue(store: store)
        let resolver = RuleResolver(rules: DefaultRules.asRules)
        #expect(try q.enqueue(ytItem, resolver: resolver, now: now) == false)
        #expect(try q.enqueue(appItem, resolver: resolver, now: now))
        #expect(try q.enqueue(appItem, resolver: resolver, now: now) == false)
        #expect(q.pendingCount == 1)
    }

    @Test func batchesAndBackoff() throws {
        let store = try Store(path: ":memory:")
        let q = ClassifierQueue(store: store, maxBatch: 2)
        let empty = RuleResolver(rules: [])
        for i in 0..<3 {
            try q.enqueue(ClassifyItem(key: ItemKey(kind: .app, key: "a\(i)"), appName: "A", sampleTitle: nil), resolver: empty, now: now)
        }
        let batch = q.nextBatch()
        #expect(batch.count == 2)
        #expect(q.pendingCount == 1)
        let inserted = try q.complete(batch: batch, results: [batch[0].key: .admin], now: now)
        #expect(inserted == 1)
        #expect(try store.classifyAttempt(for: batch[1].key)?.failures == 1)
        #expect(try q.enqueue(batch[1], resolver: empty, now: now.addingTimeInterval(60)) == false)
        #expect(try q.enqueue(batch[1], resolver: empty, now: now.addingTimeInterval(3_601)))
        #expect(ClassifierQueue.backoff(failures: 1) == 3_600)
        #expect(ClassifierQueue.backoff(failures: 3) == 14_400)
        #expect(ClassifierQueue.backoff(failures: 10) == 86_400)
    }

    @Test func claudeNeverOverwritesUserRules() throws {
        let store = try Store(path: ":memory:")
        let q = ClassifierQueue(store: store)
        try store.setUserRule(appItem.key, category: .writing, at: now)
        _ = try q.complete(batch: [appItem], results: [appItem.key: .code], now: now)
        #expect(RuleResolver(rules: try store.allRules()).category(for: appItem.key) == .writing)
    }
}
