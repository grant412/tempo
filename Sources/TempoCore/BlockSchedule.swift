import Foundation

/// The Distraction block's weekly window (site blocking spec 5.1).
public struct BlockSchedule: Equatable, Sendable {
    public var enabled: Bool
    /// Calendar weekday numbers: 1 is Sunday, 7 is Saturday.
    public var weekdays: Set<Int>
    /// Minutes after midnight, 0 to 1439.
    public var startMinute: Int
    public var endMinute: Int

    public init(enabled: Bool, weekdays: Set<Int>, startMinute: Int, endMinute: Int) {
        self.enabled = enabled
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// Monday to Friday. Settings store weekdays as a mask with bit (weekday - 1).
    public static let workweekMask = 0b0111110

    public static func weekdays(mask: Int) -> Set<Int> {
        Set((1...7).filter { mask & (1 << ($0 - 1)) != 0 })
    }

    public static func mask(weekdays: Set<Int>) -> Int {
        weekdays.filter { (1...7).contains($0) }.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    /// End at or before start: the window ends the next day. Equal times make a full 24 hours.
    public var runsPastMidnight: Bool { endMinute <= startMinute }

    /// The window containing `date`, or nil. A window belongs to the day it starts on, so the
    /// one that started yesterday is checked too. Start is inclusive, end exclusive.
    public func window(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard enabled else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let window = window(startingOn: day, calendar: calendar),
                  window.start <= date, date < window.end else { continue }
            return window
        }
        return nil
    }

    private func window(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        let endDay: Date? = runsPastMidnight ? calendar.date(byAdding: .day, value: 1, to: day) : day
        guard let endDay,
              let start = Self.time(startMinute, on: day, calendar: calendar),
              let end = Self.time(endMinute, on: endDay, calendar: calendar),
              end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Wall-clock time on that day, so DST days keep the chosen times.
    private static func time(_ minute: Int, on day: Date, calendar: Calendar) -> Date? {
        var c = calendar.dateComponents([.year, .month, .day], from: day)
        c.hour = minute / 60
        c.minute = minute % 60
        return calendar.date(from: c)
    }
}
