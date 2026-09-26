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

    @Test func hourLabels() {
        #expect(Format.hourLabel(0) == "12 AM")
        #expect(Format.hourLabel(8) == "8 AM")
        #expect(Format.hourLabel(12) == "12 PM")
        #expect(Format.hourLabel(18) == "6 PM")
    }
}
