import Foundation

public struct CategoryTotal: Equatable, Sendable {
    public let category: CategoryID
    public let duration: TimeInterval
}

public struct DaySummary: Equatable, Sendable {
    public let total: TimeInterval
    public let firstActivity: Date?
    public let lastActivity: Date?
    public let longestBlock: Block?
    public let distraction: TimeInterval
    /// Non-zero categories, longest first.
    public let categories: [CategoryTotal]

    public static let empty = DaySummary(total: 0, firstActivity: nil, lastActivity: nil, longestBlock: nil,
                                         distraction: 0, categories: [])

    public static func make(segments: [Segment], day: DateInterval, resolver: RuleResolver,
                            layout: DayLayout) -> DaySummary {
        let clipped = segments.compactMap { $0.clipped(to: day) }
        var totals: [CategoryID: TimeInterval] = [:]
        for s in clipped { totals[resolver.category(for: s.itemKey), default: 0] += s.duration }
        let categories = totals
            .filter { $0.value > 0 }
            .map { CategoryTotal(category: $0.key, duration: $0.value) }
            .sorted {
                $0.duration != $1.duration ? $0.duration > $1.duration
                    : CategoryID.allCases.firstIndex(of: $0.category)! < CategoryID.allCases.firstIndex(of: $1.category)!
            }
        return DaySummary(
            total: clipped.reduce(0) { $0 + $1.duration },
            firstActivity: clipped.map(\.start).min(),
            lastActivity: clipped.map(\.end).max(),
            longestBlock: layout.blocks.max { $0.duration < $1.duration },
            distraction: totals[.distraction] ?? 0,
            categories: categories)
    }
}

/// What tracking recorded during one focus session, for the notes window (focus timer spec 3.4).
public struct SessionRecap: Equatable, Sendable {
    public let total: TimeInterval
    /// Non-zero categories, longest first, same order rules as DaySummary.
    public let categories: [CategoryTotal]
    /// The three longest apps or sites.
    public let topNames: [String]

    public static func make(segments: [Segment], interval: DateInterval, resolver: RuleResolver) -> SessionRecap {
        let clipped = segments.compactMap { $0.clipped(to: interval) }
        let summary = DaySummary.make(segments: clipped, day: interval, resolver: resolver, layout: .empty)
        let names = BlockBuilder.items(for: clipped, resolver: resolver).prefix(3).map(\.displayName)
        return SessionRecap(total: summary.total, categories: summary.categories, topNames: Array(names))
    }
}

public struct WeekDay: Equatable, Sendable {
    public let day: DateInterval
    public let totals: [CategoryID: TimeInterval]
    public var total: TimeInterval { totals.values.reduce(0, +) }
}

public enum WeekSummary {
    /// Monday 00:00 to the next Monday 00:00 in the given calendar's time zone.
    public static func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        var cal = calendar
        cal.firstWeekday = 2
        return cal.dateInterval(of: .weekOfYear, for: date)!
    }

    public static func days(segments: [Segment], week: DateInterval, calendar: Calendar,
                            resolver: RuleResolver) -> [WeekDay] {
        (0..<7).compactMap { offset -> WeekDay? in
            guard let start = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let day = DateInterval(start: start, end: end)
            var totals: [CategoryID: TimeInterval] = [:]
            for s in segments {
                if let c = s.clipped(to: day) { totals[resolver.category(for: c.itemKey), default: 0] += c.duration }
            }
            return WeekDay(day: day, totals: totals)
        }
    }
}
