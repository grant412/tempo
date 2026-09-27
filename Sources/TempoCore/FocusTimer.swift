import Foundation

/// A running focus countdown (focus timer spec 4.1). Tracking keeps running underneath it.
public struct FocusTimer: Equatable, Sendable {
    public let start: Date
    public let planned: TimeInterval

    public init(start: Date, planned: TimeInterval) {
        self.start = start
        self.planned = planned
    }

    public var end: Date { start.addingTimeInterval(planned) }

    /// Never negative.
    public func remaining(at now: Date) -> TimeInterval { max(0, end.timeIntervalSince(now)) }

    public func isDone(at now: Date) -> Bool { now >= end }

    /// 5 min, 15 min, 30 min, 1 hour, 2 hours.
    public static let presets: [TimeInterval] = [300, 900, 1800, 3600, 7200]

    public static let customRange = 1...600

    /// Whole minutes from the Custom field, 1 to 600, or nil.
    public static func customMinutes(_ text: String) -> Int? {
        guard let n = Int(text.trimmingCharacters(in: .whitespaces)), customRange.contains(n) else { return nil }
        return n
    }
}
