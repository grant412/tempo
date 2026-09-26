import Foundation
import Testing
@testable import TempoCore

private func d(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }
private let term = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: "zsh", domain: nil)
private let yt = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: "YouTube", domain: "youtube.com")
private let all = DateInterval(start: d(-10), end: d(10_000))

struct SegmentRecorderTests {
    @Test func flushesEveryThirtySecondsAndOnClose() throws {
        let store = try Store(path: ":memory:")
        let rec = SegmentRecorder(store: store)
        var b = SegmentBuilder()
        try rec.apply(b.tick(at: d(0), presence: .active(term)), now: d(0))
        #expect(rec.openID != nil)
        try rec.apply(b.tick(at: d(20), presence: .active(term)), now: d(20))
        #expect(try store.segments(overlapping: all).first?.end == d(0))
        try rec.apply(b.tick(at: d(30), presence: .active(term)), now: d(30))
        #expect(try store.segments(overlapping: all).first?.end == d(30))
        let closed = try rec.apply(b.tick(at: d(45), presence: .away), now: d(45))
        #expect(closed.count == 1)
        #expect(closed[0].id == (try store.segments(overlapping: all).first?.id))
        #expect(try store.segments(overlapping: all).first?.end == d(45))
        #expect(rec.openID == nil)
    }

    @Test func discardedSegmentsAreDeleted() throws {
        let store = try Store(path: ":memory:")
        let rec = SegmentRecorder(store: store)
        var b = SegmentBuilder()
        try rec.apply(b.tick(at: d(0), presence: .active(term)), now: d(0))
        try rec.apply(b.tick(at: d(0.4), presence: .away), now: d(0.4))
        #expect(try store.segments(overlapping: all).isEmpty)
        #expect(rec.openID == nil)
    }

    @Test func closeFailureDoesNotLeakIntoNextSegment() throws {
        let store = try Store(path: ":memory:")
        try store.exec("""
            CREATE TRIGGER fail_close BEFORE UPDATE ON segments
            WHEN NEW.end = \(d(40).timeIntervalSince1970)
            BEGIN SELECT RAISE(ABORT, 'boom'); END;
            """)
        let rec = SegmentRecorder(store: store)
        var b = SegmentBuilder()
        for t in stride(from: 0.0, through: 35, by: 5) {
            try rec.apply(b.tick(at: d(t), presence: .active(term)), now: d(t))
        }
        let terminalID = try #require(rec.openID)
        let switchEvents = b.tick(at: d(40), presence: .active(yt))
        #expect(throws: (any Error).self) { try rec.apply(switchEvents, now: d(40)) }
        let chromeID = try #require(rec.openID)
        #expect(chromeID != terminalID)
        for t in stride(from: 45.0, through: 90, by: 5) {
            try rec.apply(b.tick(at: d(t), presence: .active(yt)), now: d(t))
        }
        let closed = try rec.apply(b.tick(at: d(95), presence: .away), now: d(95))

        let rows = try store.segments(overlapping: all)
        #expect(rows.count == 2)
        let terminalRow = rows.first { $0.snapshot.bundleID == term.bundleID }
        let chromeRow = rows.first { $0.snapshot.bundleID == yt.bundleID }
        #expect(terminalRow?.id == terminalID)
        #expect(terminalRow?.end == d(25))
        #expect(chromeRow?.id == chromeID)
        #expect(chromeRow?.start == d(40))
        #expect(chromeRow?.end == d(95))
        #expect(!rows.contains { $0.snapshot.bundleID == term.bundleID && $0.end > d(40) })
        #expect(closed.count == 1)
        #expect(closed.first?.id == chromeID)
        #expect(closed.first?.snapshot.bundleID == yt.bundleID)
    }

    @Test func insertFailureRetries() throws {
        let store = try Store(path: ":memory:")
        try store.exec("""
            CREATE TRIGGER fail_insert BEFORE INSERT ON segments
            WHEN (SELECT count(*) FROM meta WHERE key = 'fail_insert') = 1
            BEGIN SELECT RAISE(ABORT, 'boom'); END;
            """)
        try store.setMeta("fail_insert", "1")
        let rec = SegmentRecorder(store: store)
        var b = SegmentBuilder()
        let opening = b.tick(at: d(0), presence: .active(term))
        #expect(throws: (any Error).self) { try rec.apply(opening, now: d(0)) }
        #expect(rec.openID == nil)
        #expect(try store.segments(overlapping: all).isEmpty)

        try store.exec("DELETE FROM meta WHERE key = 'fail_insert'")
        try rec.apply(b.tick(at: d(5), presence: .active(term)), now: d(5))
        let id = try #require(rec.openID)
        let rows = try store.segments(overlapping: all)
        #expect(rows.count == 1)
        #expect(rows.first?.id == id)
        #expect(rows.first?.start == d(0))
        #expect(rows.first?.end == d(5))

        let closed = try rec.apply(b.tick(at: d(10), presence: .away), now: d(10))
        #expect(closed.first?.id == id)
        #expect(try store.segments(overlapping: all).first?.end == d(10))
    }

    @Test func appSwitchInOneBatch() throws {
        let store = try Store(path: ":memory:")
        let rec = SegmentRecorder(store: store)
        var b = SegmentBuilder()
        try rec.apply(b.tick(at: d(0), presence: .active(term)), now: d(0))
        try rec.apply(b.tick(at: d(5), presence: .active(term)), now: d(5))
        let terminalID = try #require(rec.openID)
        let events = b.tick(at: d(10), presence: .active(yt))
        #expect(events.count == 2)
        let closed = try rec.apply(events, now: d(10))
        #expect(closed.count == 1)
        #expect(closed.first?.id == terminalID)
        #expect(closed.first?.end == d(10))
        let chromeID = try #require(rec.openID)
        #expect(chromeID != terminalID)
        let rows = try store.segments(overlapping: all)
        #expect(rows.map(\.id) == [terminalID, chromeID])
        #expect(rows.first?.end == d(10))
        #expect(rows.last?.start == d(10))
        #expect(rows.last?.snapshot == yt)
    }
}
