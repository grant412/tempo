import Foundation
import Testing
@testable import TempoCore

struct VisibleHoursTests {
    private func range(_ marks: [Date]) -> DateInterval {
        VisibleHours.range(day: Fixtures.day, calendar: Fixtures.calendar, marks: marks)
    }

    @Test func eightToSixWithNoMarks() {
        #expect(range([]) == DateInterval(start: Fixtures.at(8 * 60), end: Fixtures.at(18 * 60)))
    }

    @Test func earlyActivityWidensTheStartToTheHourBefore() {
        // First activity 6:40 AM, last 5:00 PM: 5 AM to 6 PM.
        #expect(range([Fixtures.at(400), Fixtures.at(1020)])
            == DateInterval(start: Fixtures.at(300), end: Fixtures.at(1080)))
    }

    @Test func startStopsAtMidnight() {
        #expect(range([Fixtures.at(20)]).start == Fixtures.day.start)
    }

    @Test func focusSessionAfterTheLastActivityWidensTheEnd() {
        // Tracking 9:00 AM to 6:55 PM, then a 7:30 to 8:30 PM timer while stopped: 8 AM to 9 PM.
        let r = range([Fixtures.at(540), Fixtures.at(1135), Fixtures.at(1170), Fixtures.at(1230)])
        #expect(r == DateInterval(start: Fixtures.at(480), end: Fixtures.at(1260)))
    }

    @Test func markAtTheEndOfTheDayRunsToTheEnd() {
        // A segment that ran past midnight is clipped to day.end; that is hour 24, not hour 0.
        #expect(range([Fixtures.at(540), Fixtures.day.end]).end == Fixtures.day.end)
        #expect(range([Fixtures.at(540), Fixtures.at(1400)]).end == Fixtures.day.end)
    }

    @Test func nowWidensBothWays() {
        // The model adds now as a mark when showing today.
        #expect(range([Fixtures.at(315)]).start == Fixtures.at(240))
        #expect(range([Fixtures.at(540), Fixtures.at(1000), Fixtures.at(1305)]).end == Fixtures.at(1320))
    }

    @Test func lateSessionOnTheFallBackDayIsInside() {
        // 2026-11-01 in New York is 25 hours long. Tracking ends 6:55 PM, then a 7:30 to 7:50 PM timer.
        let cal = Fixtures.calendar
        func time(_ hour: Int, _ minute: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: hour, minute: minute))!
        }
        let day = cal.dateInterval(of: .day, for: time(12, 0))!
        #expect(day.duration == 25 * 3600)
        let r = VisibleHours.range(day: day, calendar: cal,
                                   marks: [time(9, 0), time(18, 55), time(19, 30), time(19, 50)])
        #expect(r.end == time(20, 0))
        #expect(r.start <= time(9, 0))
    }
}
