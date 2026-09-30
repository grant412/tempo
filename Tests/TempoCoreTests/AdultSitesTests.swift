import Foundation
import Testing
@testable import TempoCore

struct AdultSitesTests {
    static let sample = """
    # Title: sample
    # Entries: 5

    example-adult.com
    WWW.Upper.com
    *.wild.net
    nsfw.reddit.com
    adult
    """

    let sites = AdultSites(listText: sample)

    @Test func parsesEntriesSkippingCommentsAndBlanks() {
        #expect(sites.count == 5)
    }

    @Test func matchesExactHostsAndSubdomains() {
        #expect(sites.contains(host: "example-adult.com"))
        #expect(sites.contains(host: "cdn.example-adult.com"))
        #expect(sites.contains(host: "upper.com"))
        #expect(sites.contains(host: "wild.net"))
        #expect(sites.contains(host: "a.b.wild.net"))
        #expect(sites.contains(host: "EXAMPLE-ADULT.COM"))
    }

    @Test func subdomainEntryDoesNotBlockItsParent() {
        #expect(sites.contains(host: "nsfw.reddit.com"))
        #expect(!sites.contains(host: "reddit.com"))
        #expect(!sites.contains(host: "old.reddit.com"))
    }

    @Test func noSuffixSubstringMatch() {
        #expect(!sites.contains(host: "notexample-adult.com"))
    }

    @Test func oneLabelEntriesBlockOnlyTheTopLevelDomain() {
        #expect(sites.contains(host: "anything.adult"))
        #expect(!sites.contains(host: "adult.example.org"))
    }

    @Test func wordsBlockAnyHostContainingThem() {
        #expect(sites.contains(host: "freeporn.example"))
        #expect(sites.contains(host: "myxxxsite.org"))
        #expect(sites.contains(host: "hentaihaven.io"))
        #expect(!sites.contains(host: "github.com"))
    }

    @Test func localHostsAndAddressesNeverMatch() {
        #expect(!sites.contains(host: "porn.test:3000"))
        #expect(!sites.contains(host: "localhost:5173"))
        #expect(!sites.contains(host: "10.0.0.1"))
    }

    @Test func emptyListStillBlocksWords() {
        let empty = AdultSites(listText: "")
        #expect(empty.count == 0)
        #expect(empty.contains(host: "pornsite.com"))
        #expect(!empty.contains(host: "example-adult.com"))
    }

    @Test func shippedListLoads() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Blocking/oisd-nsfw-small.txt")
        let list = AdultSites(listText: try String(contentsOf: url, encoding: .utf8))
        #expect(list.count == 21192)
        #expect(list.contains(host: "pornhub.com"))
        #expect(list.contains(host: "xvideos.com"))
        for host in ["reddit.com", "x.com", "google.com", "tumblr.com", "imgur.com", "youtube.com", "github.com"] {
            #expect(!list.contains(host: host), "\(host) should stay open")
        }
    }
}
