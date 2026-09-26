import Foundation
import Testing
@testable import TempoCore

private typealias F = Fixtures

struct SummariesTests {
    @Test func wednesdayMatchesTheMockup() {
        let layout = BlockBuilder.build(segments: F.wednesday, day: F.day, resolver: F.resolver)
        let s = DaySummary.make(segments: F.wednesday, day: F.day, resolver: F.resolver, layout: layout)
        #expect(Format.duration(s.total) == "9h 05m")
        #expect(s.firstActivity == F.at(492))
        #expect(s.lastActivity == F.at(1085))
        #expect((s.longestBlock?.duration ?? 0) == 112 * 60)
        #expect(s.longestBlock?.category == .code)
        #expect(s.distraction == 38 * 60)
        #expect(s.categories.map(\.category) == [.code, .design, .meet, .comms, .writing, .distraction, .research, .admin, .uncategorized])
        #expect(s.categories.map { Int($0.duration / 60) } == [263, 54, 50, 43, 40, 38, 30, 15, 12])
    }

    @Test func weekStartsMondayAndSplitsDays() {
        let thursday = F.calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))!
        let week = WeekSummary.interval(containing: thursday, calendar: F.calendar)
        #expect(week.start == F.calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))!)
        let days = WeekSummary.days(segments: F.wednesday, week: week, calendar: F.calendar, resolver: F.resolver)
        #expect(days.count == 7)
        #expect(days[2].day == F.day)
        #expect(Int(days[2].total / 60) == 545)
        #expect((days[2].totals[.code] ?? 0) == 263 * 60)
        #expect(days[0].total == 0)
    }
}
