import Foundation
import Testing
@testable import TempoCore

struct RuleLockTests {
    let rules = DefaultRules.asRules
    func domain(_ host: String) -> ItemKey { ItemKey(kind: .domain, key: host) }

    @Test func movingADistractionSiteOutIsRefused() {
        #expect(!RuleLock.allows(domain("youtube.com"), newCategory: .research, rules: rules))
    }

    @Test func deletingADistractionRuleIsRefused() {
        #expect(!RuleLock.allows(domain("youtube.com"), newCategory: nil, rules: rules))
    }

    @Test func splittingASubdomainOutIsRefused() {
        #expect(!RuleLock.allows(domain("music.youtube.com"), newCategory: .research, rules: rules))
    }

    @Test func movingASiteIntoDistractionIsAllowed() {
        #expect(RuleLock.allows(domain("github.com"), newCategory: .distraction, rules: rules))
        #expect(RuleLock.allows(domain("brand-new.example"), newCategory: .distraction, rules: rules))
        #expect(RuleLock.allows(domain("youtube.com"), newCategory: .distraction, rules: rules))
    }

    @Test func otherSitesAreNeverLocked() {
        #expect(RuleLock.allows(domain("github.com"), newCategory: .research, rules: rules))
        #expect(RuleLock.allows(domain("github.com"), newCategory: nil, rules: rules))
    }

    @Test func appRulesAreNeverLocked() {
        #expect(RuleLock.allows(ItemKey(kind: .app, key: "com.spotify.client"), newCategory: .code, rules: rules))
        #expect(RuleLock.allows(ItemKey(kind: .app, key: "com.spotify.client"), newCategory: nil, rules: rules))
    }

    @Test func deletingASubdomainRuleUnderADistractionParentIsAllowed() {
        let withSub = rules + [Rule(key: domain("m.youtube.com"), category: .distraction, source: .user, updatedAt: .distantPast)]
        #expect(RuleLock.allows(domain("m.youtube.com"), newCategory: nil, rules: withSub))
    }
}
