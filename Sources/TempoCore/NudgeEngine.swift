import Foundation

public struct NudgeSettings: Equatable, Sendable {
    public var breakEnabled: Bool
    public var breakMinutes: Int
    public var distractionEnabled: Bool
    public var distractionMinutes: Int

    public init(breakEnabled: Bool = true, breakMinutes: Int = 90,
                distractionEnabled: Bool = true, distractionMinutes: Int = 20) {
        self.breakEnabled = breakEnabled
        self.breakMinutes = breakMinutes
        self.distractionEnabled = distractionEnabled
        self.distractionMinutes = distractionMinutes
    }
}

public struct Nudge: Equatable, Sendable {
    public let kind: NudgeKind
    public let at: Date
    public let minutes: Int
    public let since: Date
    public let names: [String]
}

public struct NudgeEngine: Sendable {
    public var settings: NudgeSettings
    public static let breakGap: TimeInterval = 300
    public static let distractionGrace: TimeInterval = 60

    private var streakStart: Date?
    private var awayStart: Date?
    private var breakFired = false
    private var distractionStart: Date?
    private var otherSince: Date?
    private var distractionFired = false
    private var distractionNames: [String] = []

    public init(settings: NudgeSettings = NudgeSettings()) {
        self.settings = settings
    }

    public mutating func observe(at now: Date, presence: Presence, category: CategoryID?) -> [Nudge] {
        switch presence {
        case .away:
            if awayStart == nil { awayStart = now }
            endDistraction()
            return []
        case .idle(let lastInput):
            if awayStart == nil { awayStart = lastInput }
            endDistraction()
            return []
        case .active(let snapshot):
            var out: [Nudge] = []
            if let away = awayStart {
                if now.timeIntervalSince(away) >= Self.breakGap {
                    streakStart = now
                    breakFired = false
                }
                awayStart = nil
            }
            if streakStart == nil { streakStart = now }
            if settings.breakEnabled, !breakFired, let start = streakStart,
               now.timeIntervalSince(start) >= TimeInterval(settings.breakMinutes * 60) {
                breakFired = true
                out.append(Nudge(kind: .breakTime, at: now, minutes: settings.breakMinutes, since: start, names: []))
            }

            if category == .distraction {
                if distractionStart == nil {
                    distractionStart = now
                    distractionFired = false
                    distractionNames = []
                }
                otherSince = nil
                let name = snapshot.displayName
                if !distractionNames.contains(name) { distractionNames.append(name) }
                if settings.distractionEnabled, !distractionFired, let start = distractionStart,
                   now.timeIntervalSince(start) >= TimeInterval(settings.distractionMinutes * 60) {
                    distractionFired = true
                    out.append(Nudge(kind: .distraction, at: now, minutes: settings.distractionMinutes,
                                     since: start, names: Array(distractionNames.prefix(2))))
                }
            } else if distractionStart != nil {
                if let other = otherSince {
                    if now.timeIntervalSince(other) >= Self.distractionGrace { endDistraction() }
                } else {
                    otherSince = now
                }
            }
            return out
        }
    }

    private mutating func endDistraction() {
        distractionStart = nil
        otherSince = nil
        distractionFired = false
        distractionNames = []
    }
}

public enum NudgeCopy {
    public static func title(_ n: Nudge) -> String {
        switch n.kind {
        case .breakTime: "Time for a break"
        case .distraction: "\(n.minutes) minutes on Distraction"
        }
    }

    public static func body(_ n: Nudge, timeZone: TimeZone = .current) -> String {
        switch n.kind {
        case .breakTime:
            return "You've been at it for \(n.minutes) minutes straight. A five minute break resets the clock."
        case .distraction:
            let names = n.names.isEmpty ? "Distraction" : n.names.joined(separator: " and ")
            let since = Format.clock(n.since, timeZone: timeZone)
                .replacingOccurrences(of: " AM", with: "")
                .replacingOccurrences(of: " PM", with: "")
            return "You've been on \(names) since \(since). Ready to get back to it?"
        }
    }
}
