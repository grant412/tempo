import Foundation
import TempoCore

enum AppSettings {
    enum Keys {
        static let idleMinutes = "idleMinutes"
        static let breakEnabled = "breakEnabled"
        static let breakMinutes = "breakMinutes"
        static let distractionEnabled = "distractionEnabled"
        static let distractionMinutes = "distractionMinutes"
        static let keyRejected = "keyRejected"
        static let firstLaunchDone = "firstLaunchDone"
        static let blockEnabled = "blockEnabled"
        static let blockWeekdayMask = "blockWeekdayMask"
        static let blockStartMinute = "blockStartMinute"
        static let blockEndMinute = "blockEndMinute"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.idleMinutes: 5, Keys.breakEnabled: true, Keys.breakMinutes: 90,
            Keys.distractionEnabled: true, Keys.distractionMinutes: 20,
            Keys.keyRejected: false, Keys.firstLaunchDone: false,
            Keys.blockEnabled: false, Keys.blockWeekdayMask: BlockSchedule.workweekMask,
            Keys.blockStartMinute: 540, Keys.blockEndMinute: 1020,
        ])
    }

    static var idleSeconds: TimeInterval {
        TimeInterval(max(1, UserDefaults.standard.integer(forKey: Keys.idleMinutes)) * 60)
    }

    static var nudgeSettings: NudgeSettings {
        let d = UserDefaults.standard
        return NudgeSettings(breakEnabled: d.bool(forKey: Keys.breakEnabled),
                             breakMinutes: max(1, d.integer(forKey: Keys.breakMinutes)),
                             distractionEnabled: d.bool(forKey: Keys.distractionEnabled),
                             distractionMinutes: max(1, d.integer(forKey: Keys.distractionMinutes)))
    }

    /// The Distraction block window (site blocking spec 4.1). Defaults: off, Mon to Fri, 9 to 5.
    static var blockSchedule: BlockSchedule {
        let d = UserDefaults.standard
        return BlockSchedule(enabled: d.bool(forKey: Keys.blockEnabled),
                             weekdays: BlockSchedule.weekdays(mask: d.integer(forKey: Keys.blockWeekdayMask)),
                             startMinute: min(max(d.integer(forKey: Keys.blockStartMinute), 0), 1439),
                             endMinute: min(max(d.integer(forKey: Keys.blockEndMinute), 0), 1439))
    }
}

enum AppPaths {
    static var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tempo", isDirectory: true)
    }
    static var database: URL { dataDirectory.appendingPathComponent("tempo.db") }
}
