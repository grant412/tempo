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
}
