import Foundation

public enum Format {
    /// Whole minutes, floored: "0m", "28m", "1h 52m", "9h 05m".
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h " + String(format: "%02d", m) + "m" : "\(m)m"
    }

    /// "8:12 AM", "5:41 PM".
    public static func clock(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// "12 AM", "8 AM", "12 PM", "6 PM".
    public static func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve) " + (h < 12 ? "AM" : "PM")
    }

    /// Time left on a timer: "24:13", "5:00", "0:07", "1:59:12". Counts up to the next whole
    /// second, so a new 25 minute timer reads "25:00" and the last second reads "0:01".
    /// The millisecond shave keeps Date arithmetic dust from showing "25:01".
    public static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int((seconds - 0.001).rounded(.up)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? "\(h):" + String(format: "%02d:%02d", m, s) : "\(m):" + String(format: "%02d", s)
    }

    /// A timer length: "5 min", "45 min", "1 hour", "2 hours", "1h 30m". At least "1 min".
    public static func minutesLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        if minutes % 60 == 0 { return minutes == 60 ? "1 hour" : "\(minutes / 60) hours" }
        return duration(TimeInterval(minutes * 60))
    }
}
