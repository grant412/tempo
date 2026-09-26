import Foundation
import Testing
@testable import TempoCore

private let t = Date(timeIntervalSince1970: 0)
private func rule(_ kind: RuleKind, _ key: String, _ cat: CategoryID?, _ src: RuleSource = .defaultRule) -> Rule {
    Rule(key: ItemKey(kind: kind, key: key), category: cat, source: src, updatedAt: t)
}

struct RuleResolverTests {
    @Test func exactDomainBeatsParent() {
        let r = RuleResolver(rules: [rule(.domain, "google.com", .research), rule(.domain, "mail.google.com", .comms)])
        #expect(r.category(for: ItemKey(kind: .domain, key: "mail.google.com")) == .comms)
        #expect(r.category(for: ItemKey(kind: .domain, key: "scholar.google.com")) == .research)
    }

    @Test func tombstoneFallsThroughToParent() {
        let r = RuleResolver(rules: [rule(.domain, "google.com", .research), rule(.domain, "mail.google.com", nil, .user)])
        #expect(r.category(for: ItemKey(kind: .domain, key: "mail.google.com")) == .research)
    }

    @Test func unknownIsUncategorized() {
        let r = RuleResolver(rules: [rule(.app, "com.google.Chrome", .research)])
        #expect(r.category(for: ItemKey(kind: .domain, key: "localhost:5173")) == .uncategorized)
        #expect(r.category(for: ItemKey(kind: .app, key: "com.example.new")) == .uncategorized)
        #expect(r.category(for: ItemKey(kind: .app, key: "com.google.Chrome")) == .research)
    }

    @Test func isKnownCountsTombstonesAndParents() {
        let r = RuleResolver(rules: [rule(.domain, "google.com", .research), rule(.app, "com.x", nil, .user)])
        #expect(r.isKnown(ItemKey(kind: .domain, key: "docs.google.com")))
        #expect(r.isKnown(ItemKey(kind: .app, key: "com.x")))
        #expect(!r.isKnown(ItemKey(kind: .domain, key: "example.org")))
    }

    @Test func defaultsCoverTheSpecExamples() {
        let r = RuleResolver(rules: DefaultRules.asRules)
        #expect(r.category(for: ItemKey(kind: .app, key: "com.anthropic.claudefordesktop")) == .code)
        #expect(r.category(for: ItemKey(kind: .domain, key: "youtube.com")) == .distraction)
        #expect(r.category(for: ItemKey(kind: .domain, key: "dash.cloudflare.com")) == .admin)
        #expect(r.category(for: ItemKey(kind: .domain, key: "developers.cloudflare.com")) == .research)
        #expect(r.category(for: ItemKey(kind: .domain, key: "meet.google.com")) == .meet)
        #expect(r.category(for: ItemKey(kind: .app, key: "com.microsoft.teams2")) == .meet)
    }

    @Test func seedingIsIdempotentAndRespectsUserRules() throws {
        let store = try Store(path: ":memory:")
        try store.setUserRule(ItemKey(kind: .domain, key: "youtube.com"), category: .research, at: t)
        try DefaultRules.seed(into: store, at: t)
        let count = try store.allRules().count
        try DefaultRules.seed(into: store, at: t)
        #expect(try store.allRules().count == count)
        #expect(count == DefaultRules.entries.count)
        let r = RuleResolver(rules: try store.allRules())
        #expect(r.category(for: ItemKey(kind: .domain, key: "youtube.com")) == .research)
        #expect(try store.meta("seed_version") == String(DefaultRules.version))
    }
}
