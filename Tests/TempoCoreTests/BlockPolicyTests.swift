import Foundation
import Testing
@testable import TempoCore

struct BlockPolicyTests {
    let adult = AdultSites(listText: "adultsite.com\n")
    let window = DateInterval(start: Fixtures.at(540), end: Fixtures.at(1020))

    func policy(inWindow: Bool, resolver: RuleResolver = Fixtures.resolver) -> BlockPolicy {
        BlockPolicy(adult: adult, resolver: resolver, window: inWindow ? window : nil)
    }

    @Test func adultIsBlockedInsideAndOutsideTheWindow() {
        #expect(policy(inWindow: false).action(for: "https://adultsite.com/x") == .blockAdult)
        #expect(policy(inWindow: true).action(for: "https://www.adultsite.com/") == .blockAdult)
    }

    @Test func adultWinsOverDistraction() {
        let rules = DefaultRules.asRules + [Rule(key: ItemKey(kind: .domain, key: "adultsite.com"),
                                                 category: .distraction, source: .user, updatedAt: .distantPast)]
        #expect(policy(inWindow: true, resolver: RuleResolver(rules: rules)).action(for: "https://adultsite.com/") == .blockAdult)
    }

    @Test func distractionOnlyInsideTheWindow() {
        #expect(policy(inWindow: true).action(for: "https://www.youtube.com/watch?v=1")
                == .blockDistraction(site: "youtube.com", until: window.end))
        #expect(policy(inWindow: false).action(for: "https://www.youtube.com/watch?v=1") == .allow)
    }

    @Test func subdomainIsBlockedByItsParentsRule() {
        #expect(policy(inWindow: true).action(for: "https://m.youtube.com/")
                == .blockDistraction(site: "m.youtube.com", until: window.end))
    }

    @Test func otherCategoriesAndUnsortedSitesAreAllowed() {
        #expect(policy(inWindow: true).action(for: "https://github.com/") == .allow)
        #expect(policy(inWindow: true).action(for: "https://unsorted-site.example/") == .allow)
    }

    @Test func safeSearchRewriteInsideAndOutsideTheWindow() {
        let expected = BlockAction.rewrite("https://www.google.com/search?q=a&safe=active")
        #expect(policy(inWindow: false).action(for: "https://www.google.com/search?q=a") == expected)
        #expect(policy(inWindow: true).action(for: "https://www.google.com/search?q=a") == expected)
    }

    @Test func nonWebURLsAreAllowed() {
        let page = "file:///Applications/Tempo.app/Contents/Resources/Blocking/blocked.html?kind=adult"
        #expect(policy(inWindow: true).action(for: page) == .allow)
        #expect(policy(inWindow: true).action(for: "chrome://newtab/") == .allow)
        #expect(policy(inWindow: true).action(for: "about:blank") == .allow)
    }
}
