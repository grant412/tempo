import Foundation
import Testing
@testable import TempoCore

private typealias F = Fixtures

/// The mockup Wednesday has a 5 minute gap at 10:05 AM and a 43 minute lunch from 12:52 to 1:35 PM.
struct KeyboardStretchTests {
    private let tz = F.calendar.timeZone

    /// The line with its no-break spaces read as plain spaces.
    private func text(_ s: KeyboardStretch?) -> String? {
        s?.line(timeZone: tz).replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test func nothingRecordedIsNil() {
        #expect(KeyboardStretch.make(segments: [], day: F.day, now: F.at(600)) == nil)
    }

    @Test func shortGapsStayInsideTheStretch() {
        let morning = F.wednesday.filter { $0.end <= F.at(772) }
        let s = KeyboardStretch.make(segments: morning, day: F.day, now: F.at(772))
        #expect(s == .atKeyboard(since: F.at(492), awayBefore: nil))
        #expect(text(s) == "at the keyboard since 8:12 AM")
    }

    @Test func aLongBreakRestartsTheStretch() {
        let s = KeyboardStretch.make(segments: F.wednesday, day: F.day, now: F.at(1085))
        #expect(s == .atKeyboard(since: F.at(815), awayBefore: 43 * 60))
        #expect(text(s) == "at the keyboard since 1:35 PM, after 43m away")
    }

    @Test func fifteenMinutesWithNothingIsAway() {
        #expect(KeyboardStretch.make(segments: F.wednesday, day: F.day, now: F.at(1099))
            == .atKeyboard(since: F.at(815), awayBefore: 43 * 60))
        let s = KeyboardStretch.make(segments: F.wednesday, day: F.day, now: F.at(1100))
        #expect(s == .away(since: F.at(1085)))
        #expect(text(s) == "away from the keyboard since 6:05 PM")
    }

    @Test func breakIsFifteenMinutesOrMore() {
        let fourteen = [F.seg(540, 600, F.terminal), F.seg(614, 630, F.notes)]
        #expect(KeyboardStretch.make(segments: fourteen, day: F.day, now: F.at(630))
            == .atKeyboard(since: F.at(540), awayBefore: nil))
        let fifteen = [F.seg(540, 600, F.terminal), F.seg(615, 630, F.notes)]
        #expect(KeyboardStretch.make(segments: fifteen, day: F.day, now: F.at(630))
            == .atKeyboard(since: F.at(615), awayBefore: 15 * 60))
    }

    /// Two hours away midday, then back: the line names the return, not the morning.
    @Test func twoHourBreakReadsInHours() {
        let day = [F.seg(510, 720, F.terminal), F.seg(844, 900, F.figma)]
        let s = KeyboardStretch.make(segments: day, day: F.day, now: F.at(900))
        #expect(text(s) == "at the keyboard since 2:04 PM, after 2h 04m away")
    }

    /// A narrow card may wrap the line, but never inside a time or a duration.
    @Test func timesAndDurationsDoNotBreak() {
        let day = [F.seg(510, 720, F.terminal), F.seg(844, 900, F.figma)]
        let line = KeyboardStretch.make(segments: day, day: F.day, now: F.at(900))?.line(timeZone: tz)
        #expect(line == "at the keyboard since 2:04\u{00A0}PM, after 2h\u{00A0}04m away")
    }

    /// Unsorted and overlapping segments (the live one appended last) measure gaps from the latest end.
    @Test func overlapsAndOrderDoNotMatter() {
        let segs = [F.seg(600, 700, F.notes), F.seg(540, 650, F.terminal), F.seg(705, 710, F.figma)]
        #expect(KeyboardStretch.make(segments: segs, day: F.day, now: F.at(710))
            == .atKeyboard(since: F.at(540), awayBefore: nil))
    }

    /// Last night's segment that runs past midnight counts from 12:00 AM, not from yesterday.
    @Test func clipsToTheDay() {
        let late = Segment(id: nil, start: F.at(-30), end: F.at(10), snapshot: F.terminal)
        #expect(KeyboardStretch.make(segments: [late], day: F.day, now: F.at(12))
            == .atKeyboard(since: F.at(0), awayBefore: nil))
    }
}
