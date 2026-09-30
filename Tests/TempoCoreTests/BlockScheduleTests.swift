import Foundation
import Testing
@testable import TempoCore

/// 2026-09-23 is a Wednesday, 09-25 a Friday, 09-26 a Saturday. 2026-11-01 is the Sunday US
/// clocks fall back.
struct BlockScheduleTests {
    let cal = Fixtures.calendar
    let workdays = BlockSchedule(enabled: true, weekdays: [2, 3, 4, 5, 6], startMinute: 540, endMinute: 1020)

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func disabledHasNoWindow() {
        var s = workdays
        s.enabled = false
        #expect(s.window(containing: date(23, 10), calendar: cal) == nil)
    }

    @Test func insideAWorkday() {
        #expect(workdays.window(containing: date(23, 10), calendar: cal) == DateInterval(start: date(23, 9), end: date(23, 17)))
    }

    @Test func startInclusiveEndExclusive() {
        #expect(workdays.window(containing: date(23, 9), calendar: cal) != nil)
        #expect(workdays.window(containing: date(23, 8, 59), calendar: cal) == nil)
        #expect(workdays.window(containing: date(23, 17), calendar: cal) == nil)
    }

    @Test func skipsUnselectedDays() {
        #expect(workdays.window(containing: date(26, 10), calendar: cal) == nil)
    }

    @Test func overnightWindowBelongsToItsStartDay() {
        let fridayNight = BlockSchedule(enabled: true, weekdays: [6], startMinute: 21 * 60, endMinute: 60)
        #expect(fridayNight.runsPastMidnight)
        #expect(fridayNight.window(containing: date(26, 0, 30), calendar: cal) == DateInterval(start: date(25, 21), end: date(26, 1)))
        #expect(fridayNight.window(containing: date(25, 22), calendar: cal) != nil)
        #expect(fridayNight.window(containing: date(26, 1), calendar: cal) == nil)
        let saturdayNight = BlockSchedule(enabled: true, weekdays: [7], startMinute: 21 * 60, endMinute: 60)
        #expect(saturdayNight.window(containing: date(26, 0, 30), calendar: cal) == nil)
    }

    @Test func equalTimesRunAFullDay() {
        let saturday = BlockSchedule(enabled: true, weekdays: [7], startMinute: 0, endMinute: 0)
        #expect(saturday.runsPastMidnight)
        #expect(saturday.window(containing: date(26, 12), calendar: cal) == DateInterval(start: date(26, 0), end: date(27, 0)))
        #expect(saturday.window(containing: date(25, 23, 59), calendar: cal) == nil)
    }

    @Test func dstDayKeepsWallClockTimes() {
        let sundayMorning = BlockSchedule(enabled: true, weekdays: [1], startMinute: 0, endMinute: 720)
        let w = sundayMorning.window(containing: date(1, 11, month: 11), calendar: cal)
        #expect(w == DateInterval(start: date(1, 0, month: 11), end: date(1, 12, month: 11)))
        #expect(w?.duration == TimeInterval(13 * 3600))
    }

    @Test func weekdayMaskRoundTrips() {
        #expect(BlockSchedule.weekdays(mask: BlockSchedule.workweekMask) == [2, 3, 4, 5, 6])
        #expect(BlockSchedule.mask(weekdays: [2, 3, 4, 5, 6]) == 62)
        #expect(BlockSchedule.weekdays(mask: 0) == [])
        #expect(BlockSchedule.mask(weekdays: [1, 7, 9]) == 0b1000001)
    }
}
