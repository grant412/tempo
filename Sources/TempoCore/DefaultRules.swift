import Foundation

public struct DefaultRule: Equatable, Sendable {
    public let kind: RuleKind
    public let key: String
    public let category: CategoryID
}

public enum DefaultRules {
    /// Bump when entries change; seeding inserts new entries only.
    public static let version = 1

    private static func apps(_ c: CategoryID, _ ids: [String]) -> [DefaultRule] {
        ids.map { DefaultRule(kind: .app, key: $0, category: c) }
    }
    private static func sites(_ c: CategoryID, _ hosts: [String]) -> [DefaultRule] {
        hosts.map { DefaultRule(kind: .domain, key: $0, category: c) }
    }

    public static let entries: [DefaultRule] =
        apps(.code, ["com.anthropic.claudefordesktop", "com.apple.Terminal", "com.microsoft.VSCode",
                     "com.google.antigravity-ide", "com.google.antigravity"])
        + sites(.code, ["github.com", "gitlab.com", "vercel.com"])
        + apps(.design, ["com.lemon.lvoverseas", "com.apple.freeform"])
        + sites(.design, ["figma.com", "canva.com"])
        + apps(.comms, ["com.apple.mail", "com.apple.MobileSMS", "com.tinyspeck.slackmacgap",
                        "net.whatsapp.WhatsApp", "com.apple.AddressBook"])
        + sites(.comms, ["mail.google.com", "outlook.office.com", "outlook.live.com", "linkedin.com", "slack.com"])
        + apps(.meet, ["us.zoom.xos", "com.microsoft.teams2", "com.apple.FaceTime", "video.fathom.electron",
                       "com.loom.desktop"])
        + sites(.meet, ["meet.google.com", "teams.microsoft.com", "teams.live.com", "zoom.us"])
        + apps(.writing, ["md.obsidian", "com.apple.Notes", "com.apple.TextEdit", "com.apple.Stickies"])
        + sites(.writing, ["docs.google.com", "notion.so"])
        + apps(.research, ["com.google.Chrome", "com.apple.Safari", "com.apple.Preview", "com.apple.iBooksX",
                           "com.apple.Dictionary"])
        + sites(.research, ["google.com", "stackoverflow.com", "wikipedia.org", "developer.apple.com",
                            "cloudflare.com", "developers.cloudflare.com", "perplexity.ai", "chatgpt.com"])
        + apps(.admin, ["com.apple.finder", "com.apple.systempreferences", "com.apple.Passwords", "com.apple.iCal",
                        "com.apple.reminders", "com.apple.AppStore", "com.logi.optionsplus",
                        "com.privateinternetaccess.vpn", "com.ameba.SwiftBar", "com.grantfeltz.tempo"])
        + sites(.admin, ["dash.cloudflare.com", "dashboard.stripe.com", "stripe.com", "calendly.com",
                         "calendar.google.com", "drive.google.com", "supabase.com"])
        + apps(.distraction, ["com.apple.TV", "com.apple.news", "com.apple.stocks", "com.apple.Chess",
                              "com.apple.podcasts", "com.apple.Music", "com.spotify.client"])
        + sites(.distraction, ["youtube.com", "x.com", "twitter.com", "reddit.com", "instagram.com", "facebook.com",
                               "tiktok.com", "netflix.com", "twitch.tv", "espn.com", "news.ycombinator.com"])

    public static var asRules: [Rule] {
        entries.map { Rule(key: ItemKey(kind: $0.kind, key: $0.key), category: $0.category,
                           source: .defaultRule, updatedAt: Date(timeIntervalSince1970: 0)) }
    }

    /// Inserts any missing default rules when the stored seed version is behind.
    public static func seed(into store: Store, at date: Date) throws {
        let current = Int(try store.meta("seed_version") ?? "0") ?? 0
        guard current < version else { return }
        for e in entries {
            try store.insertRuleIfAbsent(ItemKey(kind: e.kind, key: e.key), category: e.category,
                                         source: .defaultRule, at: date)
        }
        try store.setMeta("seed_version", String(version))
    }
}
