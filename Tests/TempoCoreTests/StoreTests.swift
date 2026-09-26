import Foundation
import Testing
@testable import TempoCore

private func d(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }
private let term = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: "zsh", domain: nil)
private let yt = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: "Video", domain: "youtube.com")

struct StoreTests {
    @Test func migratesFreshDatabase() throws {
        let store = try Store(path: ":memory:")
        #expect(try store.meta("schema_version") == "1")
    }

    @Test func segmentInsertUpdateQueryDelete() throws {
        let store = try Store(path: ":memory:")
        let id = try store.insertSegment(Segment(id: nil, start: d(0), end: d(0), snapshot: term))
        try store.updateSegmentEnd(id: id, end: d(120))
        _ = try store.insertSegment(Segment(id: nil, start: d(200), end: d(260), snapshot: yt))
        let all = try store.segments(overlapping: DateInterval(start: d(0), end: d(1000)))
        #expect(all.count == 2)
        #expect(all[0] == Segment(id: id, start: d(0), end: d(120), snapshot: term))
        #expect(all[1].snapshot.domain == "youtube.com")
        let later = try store.segments(overlapping: DateInterval(start: d(130), end: d(1000)))
        #expect(later.count == 1)
        try store.deleteSegment(id: id)
        #expect(try store.segments(overlapping: DateInterval(start: d(0), end: d(1000))).count == 1)
    }

    @Test func userRulesOverwriteAndOthersOnlyInsert() throws {
        let store = try Store(path: ":memory:")
        let key = ItemKey(kind: .domain, key: "github.com")
        #expect(try store.insertRuleIfAbsent(key, category: .research, source: .claude, at: d(0)))
        #expect(try store.insertRuleIfAbsent(key, category: .admin, source: .defaultRule, at: d(1)) == false)
        try store.setUserRule(key, category: .code, at: d(2))
        #expect(try store.insertRuleIfAbsent(key, category: .admin, source: .claude, at: d(3)) == false)
        let rules = try store.allRules()
        #expect(rules == [Rule(key: key, category: .code, source: .user, updatedAt: d(2))])
    }

    @Test func deleteWritesTombstone() throws {
        let store = try Store(path: ":memory:")
        let key = ItemKey(kind: .app, key: "com.spotify.client")
        _ = try store.insertRuleIfAbsent(key, category: .distraction, source: .defaultRule, at: d(0))
        try store.deleteRule(key, at: d(5))
        #expect(try store.allRules() == [Rule(key: key, category: nil, source: .user, updatedAt: d(5))])
        #expect(try store.insertRuleIfAbsent(key, category: .distraction, source: .defaultRule, at: d(6)) == false)
    }

    @Test func nudgesAndAttemptsAndMeta() throws {
        let store = try Store(path: ":memory:")
        _ = try store.logNudge(.breakTime, at: d(10))
        _ = try store.logNudge(.distraction, at: d(5000))
        let n = try store.nudges(in: DateInterval(start: d(0), end: d(100)))
        #expect(n.map(\.kind) == [.breakTime])

        let key = ItemKey(kind: .domain, key: "example.com")
        #expect(try store.classifyAttempt(for: key) == nil)
        try store.recordClassifyFailure(key, at: d(1))
        try store.recordClassifyFailure(key, at: d(2))
        #expect(try store.classifyAttempt(for: key) == ClassifyAttempt(lastTry: d(2), failures: 2))
        try store.clearClassifyAttempt(key)
        #expect(try store.classifyAttempt(for: key) == nil)

        try store.setMeta("seed_version", "1")
        #expect(try store.meta("seed_version") == "1")
    }
}
