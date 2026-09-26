import Foundation

public enum CategoryID: String, CaseIterable, Codable, Sendable, Hashable {
    case code, design, comms, meet, writing, research, admin, distraction, uncategorized

    public var name: String {
        switch self {
        case .code: "Code"
        case .design: "Design"
        case .comms: "Communication"
        case .meet: "Meetings"
        case .writing: "Writing"
        case .research: "Research"
        case .admin: "Admin"
        case .distraction: "Distraction"
        case .uncategorized: "Uncategorized"
        }
    }

    /// Block fill. Uncategorized is drawn as stripes of #b8b3a8 and #c9c4ba; this is the base.
    public var fillHex: String {
        switch self {
        case .code: "#2870cc"
        case .design: "#eb6834"
        case .comms: "#1baf7a"
        case .meet: "#eda100"
        case .writing: "#e87ba4"
        case .research: "#008300"
        case .admin: "#4a3aa7"
        case .distraction: "#ec5f5e"
        case .uncategorized: "#b8b3a8"
        }
    }

    /// True when labels on this fill are white; otherwise ink.
    public var lightText: Bool { self == .code || self == .research || self == .admin }

    public var isDistraction: Bool { self == .distraction }

    /// One line per category for the Claude classifier prompt.
    public var promptDescription: String {
        switch self {
        case .code: "programming, terminals, code editors, developer tools, code hosting, AI coding assistants"
        case .design: "design tools, image and video editing, prototyping"
        case .comms: "email, chat, messaging, work social networks"
        case .meet: "video calls and meeting apps"
        case .writing: "documents, notes, word processing"
        case .research: "reading documentation, search, learning, reference sites"
        case .admin: "finance, billing, settings, file management, dashboards, scheduling"
        case .distraction: "entertainment, social feeds, video, news, shopping, games"
        case .uncategorized: "not assignable"
        }
    }

    public static var assignable: [CategoryID] { allCases.filter { $0 != .uncategorized } }
}

public enum RuleKind: String, Codable, Sendable, Hashable { case app, domain }

public struct ItemKey: Hashable, Codable, Sendable {
    public let kind: RuleKind
    public let key: String
    public init(kind: RuleKind, key: String) { self.kind = kind; self.key = key }
}

public struct Snapshot: Equatable, Hashable, Sendable {
    public var bundleID: String
    public var appName: String
    public var title: String?
    public var domain: String?

    public init(bundleID: String, appName: String, title: String?, domain: String?) {
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.domain = domain
    }

    public var itemKey: ItemKey {
        if let domain { return ItemKey(kind: .domain, key: domain) }
        return ItemKey(kind: .app, key: bundleID)
    }

    public var displayName: String { domain ?? appName }
}

public struct Segment: Equatable, Sendable {
    public var id: Int64?
    public var start: Date
    public var end: Date
    public var snapshot: Snapshot

    public init(id: Int64?, start: Date, end: Date, snapshot: Snapshot) {
        self.id = id
        self.start = start
        self.end = end
        self.snapshot = snapshot
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var itemKey: ItemKey { snapshot.itemKey }

    public func clipped(to interval: DateInterval) -> Segment? {
        let s = max(start, interval.start)
        let e = min(end, interval.end)
        guard e > s else { return nil }
        var copy = self
        copy.start = s
        copy.end = e
        return copy
    }
}

public enum RuleSource: String, Codable, Sendable {
    case defaultRule = "default"
    case user
    case claude
}

public struct Rule: Equatable, Sendable {
    public var key: ItemKey
    /// nil means a tombstone: the user deleted this rule.
    public var category: CategoryID?
    public var source: RuleSource
    public var updatedAt: Date

    public init(key: ItemKey, category: CategoryID?, source: RuleSource, updatedAt: Date) {
        self.key = key
        self.category = category
        self.source = source
        self.updatedAt = updatedAt
    }
}

public enum NudgeKind: String, Codable, Sendable { case breakTime = "break", distraction }

public struct NudgeRecord: Equatable, Identifiable, Sendable {
    public let id: Int64
    public let at: Date
    public let kind: NudgeKind
    public init(id: Int64, at: Date, kind: NudgeKind) { self.id = id; self.at = at; self.kind = kind }
}

public struct ClassifyAttempt: Equatable, Sendable {
    public let lastTry: Date
    public let failures: Int
    public init(lastTry: Date, failures: Int) { self.lastTry = lastTry; self.failures = failures }
}
