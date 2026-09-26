import Foundation
@testable import TempoCore

/// The mockup's Wednesday: 13 blocks from 8:12 AM to 6:05 PM, 9h 05m active.
enum Fixtures {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    static let dayStart = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23))!
    static let day = calendar.dateInterval(of: .day, for: dayStart)!
    static func at(_ minuteOfDay: Int) -> Date { dayStart.addingTimeInterval(TimeInterval(minuteOfDay * 60)) }

    static let resolver = RuleResolver(rules: DefaultRules.asRules)

    static func app(_ id: String, _ name: String) -> Snapshot { Snapshot(bundleID: id, appName: name, title: nil, domain: nil) }
    static func site(_ host: String) -> Snapshot { Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: nil, domain: host) }

    static let terminal = app("com.apple.Terminal", "Terminal")
    static let messages = app("com.apple.MobileSMS", "Messages")
    static let teams = app("com.microsoft.teams2", "Microsoft Teams")
    static let notes = app("com.apple.Notes", "Notes")
    static let youtube = site("youtube.com")
    static let figma = site("figma.com")
    static let cfDocs = site("developers.cloudflare.com")
    static let stripe = site("dashboard.stripe.com")
    static let localDev = site("localhost:5173")

    static func seg(_ s: Int, _ e: Int, _ snap: Snapshot) -> Segment {
        Segment(id: nil, start: at(s), end: at(e), snapshot: snap)
    }

    static let wednesday: [Segment] = [
        seg(492, 520, messages), seg(520, 532, youtube), seg(532, 605, terminal), seg(610, 660, teams),
        seg(660, 772, terminal), seg(815, 845, cfDocs), seg(845, 860, stripe), seg(860, 886, youtube),
        seg(886, 940, figma), seg(940, 980, notes), seg(980, 992, localDev), seg(992, 1070, terminal),
        seg(1070, 1085, messages),
    ]
}
