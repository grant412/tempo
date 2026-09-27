import Foundation

/// The hours the day canvas shows, so every block and focus session on the day lands inside them.
public enum VisibleHours {
    /// 8 AM to 6 PM, widened to the whole hour before the earliest mark (never before `day.start`)
    /// and the whole hour after the latest mark (never past `day.end`). A mark at or past `day.end`
    /// counts as hour 24, so the range runs to `day.end`.
    ///
    /// Marks are what must stay visible: first and last activity, focus sessions clipped to the
    /// day, and now when the day is today. Hours count time elapsed since `day.start`, the same way
    /// the canvas places points, so the marks stay inside on a daylight saving day too.
    public static func range(day: DateInterval, calendar: Calendar, marks: [Date]) -> DateInterval {
        var startHour = 8
        var endHour = 18
        if let earliest = marks.min() { startHour = min(startHour, max(0, hour(of: earliest, in: day) - 1)) }
        if let latest = marks.max() { endHour = max(endHour, min(24, hour(of: latest, in: day) + 1)) }
        let start = calendar.date(byAdding: .hour, value: startHour, to: day.start)!
        let end = endHour >= 24 ? day.end : calendar.date(byAdding: .hour, value: endHour, to: day.start)!
        return DateInterval(start: start, end: end)
    }

    /// Whole hours since `day.start`, with the date held inside the day first.
    private static func hour(of date: Date, in day: DateInterval) -> Int {
        let elapsed = min(max(0, date.timeIntervalSince(day.start)), day.duration)
        return Int((elapsed / 3600).rounded(.down))
    }
}
