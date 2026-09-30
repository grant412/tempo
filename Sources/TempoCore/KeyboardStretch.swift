import Foundation

/// The line under "Today so far": how long Grant has been at the keyboard since his last real
/// break, or how long he has been away. A gap of 15 minutes or more between segments, or since
/// the last one, is a break; shorter gaps (a coffee, a phone call) stay inside the stretch.
public enum KeyboardStretch: Equatable, Sendable {
    /// At it since `since`. `awayBefore` is the break that ended at `since`, if there was one.
    case atKeyboard(since: Date, awayBefore: TimeInterval?)
    /// Nothing recorded since `since`, 15 minutes or more ago.
    case away(since: Date)

    public static let breakLength: TimeInterval = 15 * 60

    /// nil when nothing is recorded in `day`.
    public static func make(segments: [Segment], day: DateInterval, now: Date) -> KeyboardStretch? {
        let spans = segments.compactMap { $0.clipped(to: day) }.sorted { $0.start < $1.start }
        guard let first = spans.first else { return nil }
        var start = first.start, end = first.end
        var awayBefore: TimeInterval?
        for s in spans.dropFirst() {
            let gap = s.start.timeIntervalSince(end)
            if gap >= breakLength {
                start = s.start
                awayBefore = gap
            }
            end = max(end, s.end)
        }
        if now.timeIntervalSince(end) >= breakLength { return .away(since: end) }
        return .atKeyboard(since: start, awayBefore: awayBefore)
    }

    /// "at the keyboard since 8:12 AM", "at the keyboard since 2:14 PM, after 2h 04m away",
    /// "away from the keyboard since 12:10 PM". Times and durations use no-break spaces, so a
    /// narrow card wraps between words, never inside "2h 04m" or "2:14 PM".
    public func line(timeZone: TimeZone = .current) -> String {
        func clock(_ d: Date) -> String { Self.noBreak(Format.clock(d, timeZone: timeZone)) }
        switch self {
        case .atKeyboard(let since, nil):
            return "at the keyboard since \(clock(since))"
        case .atKeyboard(let since, let away?):
            return "at the keyboard since \(clock(since)), after \(Self.noBreak(Format.duration(away))) away"
        case .away(let since):
            return "away from the keyboard since \(clock(since))"
        }
    }

    /// The menu bar's text, like Rize's without the seconds: "1:09 · 4h 20m" at the keyboard,
    /// read at `now`; just the total "4h 20m" while away or before anything is recorded today.
    public static func menuBar(_ stretch: KeyboardStretch?, total: TimeInterval, now: Date) -> String {
        let totalText = Format.duration(total)
        guard case .atKeyboard(let since, _)? = stretch else { return totalText }
        return Format.elapsed(now.timeIntervalSince(since)) + " \u{00B7} " + totalText
    }

    private static func noBreak(_ s: String) -> String { s.replacingOccurrences(of: " ", with: "\u{00A0}") }
}
