import Foundation
import Testing
@testable import TempoCore

struct ModelsTests {
    @Test func categoryOrderAndColors() {
        #expect(CategoryID.allCases.map(\.rawValue) == ["code", "design", "comms", "meet", "writing", "research", "admin", "distraction", "uncategorized"])
        #expect(CategoryID.code.fillHex == "#2870cc")
        #expect(CategoryID.code.lightText)
        #expect(!CategoryID.design.lightText)
        #expect(CategoryID.distraction.fillHex == "#ec5f5e")
        #expect(CategoryID.distraction.isDistraction)
        #expect(!CategoryID.code.isDistraction)
        #expect(CategoryID.comms.name == "Communication")
        #expect(CategoryID.assignable.count == 8)
        #expect(!CategoryID.assignable.contains(.uncategorized))
    }

    @Test func itemKeyPrefersDomain() {
        let web = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: "Home", domain: "github.com")
        #expect(web.itemKey == ItemKey(kind: .domain, key: "github.com"))
        #expect(web.displayName == "github.com")
        let app = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: "zsh", domain: nil)
        #expect(app.itemKey == ItemKey(kind: .app, key: "com.apple.Terminal"))
        #expect(app.displayName == "Terminal")
    }

    @Test func segmentClipping() {
        let snap = Snapshot(bundleID: "a", appName: "A", title: nil, domain: nil)
        let s = Segment(id: 1, start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 300), snapshot: snap)
        let day = DateInterval(start: Date(timeIntervalSince1970: 200), end: Date(timeIntervalSince1970: 1000))
        let c = s.clipped(to: day)
        #expect(c?.start == Date(timeIntervalSince1970: 200))
        #expect(c?.end == Date(timeIntervalSince1970: 300))
        #expect(c?.duration == 100)
        let outside = DateInterval(start: Date(timeIntervalSince1970: 400), end: Date(timeIntervalSince1970: 500))
        #expect(s.clipped(to: outside) == nil)
    }
}
