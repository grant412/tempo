import Foundation
import Testing
@testable import TempoCore

private let t0 = Date(timeIntervalSince1970: 2_000_000)
private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }
private let work = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: nil, domain: nil)
private let yt = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: nil, domain: "youtube.com")
private let x = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: nil, domain: "x.com")

private func run(_ e: inout NudgeEngine, from: TimeInterval, to: TimeInterval, _ snap: Snapshot, _ cat: CategoryID) -> [Nudge] {
    var out: [Nudge] = []
    var s = from
    while s <= to {
        out += e.observe(at: at(s), presence: .active(snap), category: cat)
        s += 5
    }
    return out
}

struct NudgeEngineTests {
    @Test func breakFiresOnceAtNinetyMinutes() {
        var e = NudgeEngine()
        let fired = run(&e, from: 0, to: 7200, work, .code)
        #expect(fired.count == 1)
        #expect(fired[0].kind == .breakTime)
        #expect(fired[0].at == at(5400))
        #expect(fired[0].since == at(0))
        #expect(fired[0].minutes == 90)
    }

    @Test func breakReArmsAfterFiveMinutesAway() {
        var e = NudgeEngine()
        _ = run(&e, from: 0, to: 7200, work, .code)
        _ = e.observe(at: at(7500), presence: .idle(lastInput: at(7200)), category: nil)
        let second = run(&e, from: 7560, to: 7560 + 5400, work, .code)
        #expect(second.map(\.at) == [at(7560 + 5400)])
    }

    @Test func shortAwayDoesNotReset() {
        var e = NudgeEngine()
        _ = run(&e, from: 0, to: 3000, work, .code)
        _ = e.observe(at: at(3100), presence: .away, category: nil)
        let rest = run(&e, from: 3200, to: 5400, work, .code)
        #expect(rest.map(\.at) == [at(5400)])
    }

    @Test func distractionSurvivesShortInterruption() {
        var e = NudgeEngine()
        var fired = run(&e, from: 0, to: 595, yt, .distraction)
        fired += run(&e, from: 600, to: 640, work, .code)
        fired += run(&e, from: 645, to: 1300, x, .distraction)
        let d = fired.filter { $0.kind == .distraction }
        #expect(d.count == 1)
        #expect(d[0].at == at(1200))
        #expect(d[0].names == ["youtube.com", "x.com"])
        #expect(d[0].since == at(0))
    }

    @Test func distractionEndsAfterSixtySeconds() {
        var e = NudgeEngine()
        var fired = run(&e, from: 0, to: 595, yt, .distraction)
        fired += run(&e, from: 600, to: 700, work, .code)
        fired += run(&e, from: 705, to: 1800, yt, .distraction)
        #expect(fired.filter { $0.kind == .distraction }.isEmpty)
    }

    @Test func disabledNudgesNeverFire() {
        var e = NudgeEngine(settings: NudgeSettings(breakEnabled: false, distractionEnabled: false))
        #expect(run(&e, from: 0, to: 7200, yt, .distraction).isEmpty)
    }

    @Test func copyMatchesTheMockup() {
        let tz = TimeZone(identifier: "America/New_York")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let since = cal.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14, minute: 20))!
        let b = Nudge(kind: .breakTime, at: since, minutes: 90, since: since, names: [])
        #expect(NudgeCopy.title(b) == "Time for a break")
        #expect(NudgeCopy.body(b, timeZone: tz) == "You've been at it for 90 minutes straight. A five minute break resets the clock.")
        let d = Nudge(kind: .distraction, at: since, minutes: 20, since: since, names: ["youtube.com", "x.com"])
        #expect(NudgeCopy.title(d) == "20 minutes on Distraction")
        #expect(NudgeCopy.body(d, timeZone: tz) == "You've been on youtube.com and x.com since 2:20. Ready to get back to it?")
    }
}
