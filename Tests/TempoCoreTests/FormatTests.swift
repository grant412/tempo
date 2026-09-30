import Foundation
import Testing
@testable import TempoCore

struct FormatTests {
    @Test func durationUnderAnHour() {
        #expect(Format.duration(0) == "0m")
        #expect(Format.duration(59) == "0m")
        #expect(Format.duration(28 * 60 + 30) == "28m")
    }

    @Test func durationWithHoursPadsMinutes() {
        #expect(Format.duration(112 * 60) == "1h 52m")
        #expect(Format.duration(9 * 3600 + 5 * 60) == "9h 05m")
        #expect(Format.duration(4 * 3600) == "4h 00m")
    }

    @Test func clockUsesTwelveHourTime() {
        let tz = TimeZone(identifier: "America/New_York")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d = cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 17, minute: 41))!
        #expect(Format.clock(d, timeZone: tz) == "5:41 PM")
        let m = cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 8, minute: 12))!
        #expect(Format.clock(m, timeZone: tz) == "8:12 AM")
    }

    /// Fixtures.calendar is America/New_York; 2026-09-23 is a Wednesday.
    @Test func lockEndNamesTheDayWhenNotToday() {
        let cal = Fixtures.calendar
        func at(_ day: Int, _ hour: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
        }
        let now = at(23, 10)
        #expect(Format.lockEnd(at(23, 17), now: now, calendar: cal) == "5:00 PM")
        #expect(Format.lockEnd(at(24, 1), now: now, calendar: cal) == "tomorrow at 1:00 AM")
        #expect(Format.lockEnd(at(25, 9), now: now, calendar: cal) == "Friday at 9:00 AM")
        #expect(Format.lockEnd(at(26, 9), now: now, calendar: cal) == "Saturday at 9:00 AM")
        #expect(Format.lockEnd(.distantFuture, now: now, calendar: cal) == "further notice")
    }

    /// For text that stays on screen, like the blocked page: never "tomorrow", always the day.
    @Test func dayAndClockAlwaysNamesTheDay() {
        let cal = Fixtures.calendar
        let wednesday5pm = cal.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 17))!
        let thursday1am = cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 1))!
        #expect(Format.dayAndClock(wednesday5pm, calendar: cal) == "Wednesday at 5:00 PM")
        #expect(Format.dayAndClock(thursday1am, calendar: cal) == "Thursday at 1:00 AM")
        #expect(Format.dayAndClock(.distantFuture, calendar: cal) == "further notice")
    }

    @Test func lockEndUsesTheCalendarsTimeZone() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = Fixtures.calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 10))!
        let end = Fixtures.calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 1))!
        #expect(Format.lockEnd(end, now: now, calendar: la) == "10:00 PM")
    }

    @Test func hourLabels() {
        #expect(Format.hourLabel(0) == "12 AM")
        #expect(Format.hourLabel(8) == "8 AM")
        #expect(Format.hourLabel(12) == "12 PM")
        #expect(Format.hourLabel(18) == "6 PM")
    }

    @Test func countdownUnderAnHour() {
        #expect(Format.countdown(1500) == "25:00")
        #expect(Format.countdown(1452.3) == "24:13")
        #expect(Format.countdown(300) == "5:00")
        #expect(Format.countdown(7) == "0:07")
        #expect(Format.countdown(0.2) == "0:01")
        #expect(Format.countdown(0) == "0:00")
        #expect(Format.countdown(-5) == "0:00")
    }

    @Test func countdownWithHours() {
        #expect(Format.countdown(3600) == "1:00:00")
        #expect(Format.countdown(7152) == "1:59:12")
        #expect(Format.countdown(7200) == "2:00:00")
    }

    @Test func countdownIgnoresFloatingPointDust() {
        #expect(Format.countdown(1500 + 1e-7) == "25:00")
        #expect(Format.countdown(1499 + 2e-7) == "24:59")
    }

    @Test func minutesLabels() {
        #expect(Format.minutesLabel(300) == "5 min")
        #expect(Format.minutesLabel(900) == "15 min")
        #expect(Format.minutesLabel(1800) == "30 min")
        #expect(Format.minutesLabel(2700) == "45 min")
        #expect(Format.minutesLabel(1080) == "18 min")
        #expect(Format.minutesLabel(20) == "1 min")
        #expect(Format.minutesLabel(3600) == "1 hour")
        #expect(Format.minutesLabel(7200) == "2 hours")
        #expect(Format.minutesLabel(36000) == "10 hours")
        #expect(Format.minutesLabel(5400) == "1h 30m")
    }

    @Test func elapsedIsHoursColonMinutesFloored() {
        #expect(Format.elapsed(0) == "0:00")
        #expect(Format.elapsed(59) == "0:00")
        #expect(Format.elapsed(42 * 60 + 50) == "0:42")
        #expect(Format.elapsed(69 * 60 + 22) == "1:09")
        #expect(Format.elapsed(12 * 3600 + 5 * 60) == "12:05")
        #expect(Format.elapsed(-30) == "0:00")
    }
}
