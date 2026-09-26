import Foundation
import Testing
@testable import TempoCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)
private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }
private let term = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: "zsh", domain: nil)
private let chrome = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: "YouTube", domain: "youtube.com")

struct SegmentBuilderTests {
    @Test func opensThenExtends() {
        var b = SegmentBuilder()
        let e1 = b.tick(at: at(0), presence: .active(term))
        #expect(e1 == [.opened(Segment(id: nil, start: at(0), end: at(0), snapshot: term))])
        let e2 = b.tick(at: at(5), presence: .active(term))
        #expect(e2 == [.extended(Segment(id: nil, start: at(0), end: at(5), snapshot: term))])
        #expect(b.open?.end == at(5))
    }

    @Test func changeClosesAndOpensAtSameTime() {
        var b = SegmentBuilder()
        _ = b.tick(at: at(0), presence: .active(term))
        _ = b.tick(at: at(5), presence: .active(term))
        let e = b.tick(at: at(10), presence: .active(chrome))
        #expect(e == [
            .closed(Segment(id: nil, start: at(0), end: at(10), snapshot: term)),
            .opened(Segment(id: nil, start: at(10), end: at(10), snapshot: chrome)),
        ])
    }

    @Test func idleClosesAtLastInput() {
        var b = SegmentBuilder()
        // Input stops at 100 s, but the monitor keeps reporting active until idle reaches 300 s.
        for s in stride(from: 0.0, through: 395, by: 5) { _ = b.tick(at: at(s), presence: .active(term)) }
        let e = b.tick(at: at(400), presence: .idle(lastInput: at(100)))
        #expect(e == [.closed(Segment(id: nil, start: at(0), end: at(100), snapshot: term))])
        #expect(b.open == nil)
        #expect(b.tick(at: at(405), presence: .idle(lastInput: at(100))).isEmpty)
    }

    @Test func awayClosesNow() {
        var b = SegmentBuilder()
        _ = b.tick(at: at(0), presence: .active(term))
        let e = b.tick(at: at(20), presence: .away)
        #expect(e == [.closed(Segment(id: nil, start: at(0), end: at(20), snapshot: term))])
    }

    @Test func missedTicksCloseAtPreviousTick() {
        var b = SegmentBuilder()
        _ = b.tick(at: at(0), presence: .active(term))
        _ = b.tick(at: at(5), presence: .active(term))
        let e = b.tick(at: at(600), presence: .active(term))
        #expect(e == [
            .closed(Segment(id: nil, start: at(0), end: at(5), snapshot: term)),
            .opened(Segment(id: nil, start: at(600), end: at(600), snapshot: term)),
        ])
    }

    @Test func subSecondSegmentsAreDiscarded() {
        var b = SegmentBuilder()
        _ = b.tick(at: at(0), presence: .active(term))
        let e = b.tick(at: at(0.5), presence: .away)
        #expect(e == [.discarded(Segment(id: nil, start: at(0), end: at(0.5), snapshot: term))])
    }

    @Test func titleChangeWithinSameAppExtends() {
        var b = SegmentBuilder()
        _ = b.tick(at: at(0), presence: .active(term))
        var retitled = term
        retitled.title = "make"
        let e = b.tick(at: at(5), presence: .active(retitled))
        #expect(e == [.extended(Segment(id: nil, start: at(0), end: at(5), snapshot: term))])
        #expect(b.open?.snapshot.title == "zsh")
        #expect(b.open?.start == at(0))
    }

    @Test func idleAfterTitleChurnTrimsWholeRun() {
        var b = SegmentBuilder()
        var a = term
        a.title = "a"
        var bTitle = term
        bTitle.title = "b"
        var events: [SegmentEvent] = []
        // Input stops at 100 s; the title keeps changing with no input until idle reaches 300 s.
        for (i, s) in stride(from: 0.0, through: 395, by: 5).enumerated() {
            events += b.tick(at: at(s), presence: .active(i.isMultiple(of: 2) ? a : bTitle))
        }
        events += b.tick(at: at(400), presence: .idle(lastInput: at(100)))
        let closed = events.filter { if case .closed = $0 { true } else { false } }
        #expect(closed == [.closed(Segment(id: nil, start: at(0), end: at(100), snapshot: a))])
        #expect(!events.contains { if case .discarded = $0 { true } else { false } })
        #expect(b.open == nil)
    }

    @Test func nilTitleAdoptsLaterTitle() {
        var b = SegmentBuilder()
        var untitled = term
        untitled.title = nil
        _ = b.tick(at: at(0), presence: .active(untitled))
        let e = b.tick(at: at(5), presence: .active(term))
        #expect(e == [.extended(Segment(id: nil, start: at(0), end: at(5), snapshot: term))])
        #expect(b.open?.snapshot.title == "zsh")
    }
}
