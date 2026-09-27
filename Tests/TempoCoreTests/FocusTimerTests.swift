import Foundation
import Testing
@testable import TempoCore

private func d(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }

struct FocusTimerTests {
    @Test func remainingCountsDownAndStopsAtZero() {
        let t = FocusTimer(start: d(0), planned: 1500)
        #expect(t.end == d(1500))
        #expect(t.remaining(at: d(0)) == 1500)
        #expect(abs(t.remaining(at: d(47.7)) - 1452.3) < 0.001)
        #expect(t.remaining(at: d(1500)) == 0)
        #expect(t.remaining(at: d(1600)) == 0)
    }

    @Test func doneAtAndAfterTheEnd() {
        let t = FocusTimer(start: d(0), planned: 300)
        #expect(!t.isDone(at: d(299.9)))
        #expect(t.isDone(at: d(300)))
        #expect(t.isDone(at: d(4000)))
    }

    @Test func presetsMatchTheSpec() {
        #expect(FocusTimer.presets == [300, 900, 1800, 3600, 7200])
    }

    @Test func customMinutesAcceptsWholeNumbersOneToSixHundred() {
        #expect(FocusTimer.customMinutes("45") == 45)
        #expect(FocusTimer.customMinutes(" 45 ") == 45)
        #expect(FocusTimer.customMinutes("1") == 1)
        #expect(FocusTimer.customMinutes("600") == 600)
        #expect(FocusTimer.customMinutes("0") == nil)
        #expect(FocusTimer.customMinutes("601") == nil)
        #expect(FocusTimer.customMinutes("4.5") == nil)
        #expect(FocusTimer.customMinutes("abc") == nil)
        #expect(FocusTimer.customMinutes("") == nil)
    }

    @Test func sessionKnowsWhenItEndedEarly() {
        let early = FocusSession(id: 1, start: d(0), end: d(1080), planned: 1500, note: nil)
        #expect(early.duration == 1080)
        #expect(early.endedEarly)
        #expect(early.interval == DateInterval(start: d(0), end: d(1080)))
        let full = FocusSession(id: 2, start: d(0), end: d(1500), planned: 1500, note: "done")
        #expect(!full.endedEarly)
    }
}
