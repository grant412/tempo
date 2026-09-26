import Foundation
import Testing
@testable import TempoCore

private func d(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }
private let term = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: "zsh", domain: nil)
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
}
