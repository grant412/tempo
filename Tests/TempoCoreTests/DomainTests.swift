import Testing
@testable import TempoCore

struct DomainTests {
    @Test func stripsWwwAndLowercases() {
        #expect(Domain.normalize("https://WWW.YouTube.com/watch?v=1") == "youtube.com")
        #expect(Domain.normalize("http://github.com/a/b") == "github.com")
    }

    @Test func keepsPortOnlyForLocalHosts() {
        #expect(Domain.normalize("http://localhost:5173/") == "localhost:5173")
        #expect(Domain.normalize("http://127.0.0.1:8080/x") == "127.0.0.1:8080")
        #expect(Domain.normalize("http://app.test:3000") == "app.test:3000")
        #expect(Domain.normalize("https://example.com:8443/") == "example.com")
    }

    @Test func rejectsNonWebSchemes() {
        #expect(Domain.normalize("chrome://newtab/") == nil)
        #expect(Domain.normalize("file:///Users/grant/a.html") == nil)
        #expect(Domain.normalize("not a url") == nil)
    }

    @Test func candidatesWalkParents() {
        #expect(Domain.candidates(for: "a.b.example.com") == ["a.b.example.com", "b.example.com", "example.com"])
        #expect(Domain.candidates(for: "github.com") == ["github.com"])
        #expect(Domain.candidates(for: "localhost:5173") == ["localhost:5173"])
        #expect(Domain.candidates(for: "10.0.0.1") == ["10.0.0.1"])
    }
}
