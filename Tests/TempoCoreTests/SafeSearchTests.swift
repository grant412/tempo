import Testing
@testable import TempoCore

struct SafeSearchTests {
    @Test func googleSearchGetsSafeActive() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=cats") == "https://www.google.com/search?q=cats&safe=active")
        #expect(SafeSearch.enforced("https://google.de/search?q=katzen") == "https://google.de/search?q=katzen&safe=active")
        #expect(SafeSearch.enforced("https://www.google.co.uk/search?q=a") == "https://www.google.co.uk/search?q=a&safe=active")
        #expect(SafeSearch.enforced("https://www.google.com.au/search?q=a") == "https://www.google.com.au/search?q=a&safe=active")
    }

    @Test func googleImageSearch() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=cats&udm=2") == "https://www.google.com/search?q=cats&udm=2&safe=active")
    }

    @Test func replacesAnotherValue() {
        #expect(SafeSearch.enforced("https://www.google.com/search?safe=off&q=a") == "https://www.google.com/search?q=a&safe=active")
        #expect(SafeSearch.enforced("https://www.bing.com/videos/search?q=a&adlt=off") == "https://www.bing.com/videos/search?q=a&adlt=strict")
    }

    @Test func alreadyStrictGivesNil() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=a&safe=active") == nil)
        #expect(SafeSearch.enforced("https://www.bing.com/search?q=a&adlt=strict") == nil)
        #expect(SafeSearch.enforced("https://duckduckgo.com/?q=a&kp=1") == nil)
    }

    @Test func keepsOtherParametersEncodedAsTheyWere() {
        #expect(SafeSearch.enforced("https://www.google.com/search?q=red+cats%20now&oq=red") == "https://www.google.com/search?q=red+cats%20now&oq=red&safe=active")
    }

    @Test func onlyGoogleSearchPathsOnGoogleHosts() {
        #expect(SafeSearch.enforced("https://www.google.com/") == nil)
        #expect(SafeSearch.enforced("https://www.google.com/maps/search/pizza") == nil)
        #expect(SafeSearch.enforced("https://mail.google.com/search?q=a") == nil)
        #expect(SafeSearch.enforced("https://google.evil.com/search?q=a") == nil)
    }

    @Test func bingSearchImagesAndVideos() {
        #expect(SafeSearch.enforced("https://www.bing.com/search?q=a") == "https://www.bing.com/search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://www.bing.com/images/search?q=a") == "https://www.bing.com/images/search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://cn.bing.com/search?q=a") == "https://cn.bing.com/search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://www.bing.com/maps?q=a") == nil)
    }

    @Test func duckDuckGoNeedsAQuery() {
        #expect(SafeSearch.enforced("https://duckduckgo.com/?q=a&ia=images") == "https://duckduckgo.com/?q=a&ia=images&kp=1")
        #expect(SafeSearch.enforced("https://html.duckduckgo.com/html/?q=a") == "https://html.duckduckgo.com/html/?q=a&kp=1")
        #expect(SafeSearch.enforced("https://duckduckgo.com/") == nil)
        #expect(SafeSearch.enforced("https://duckduckgo.com/?q=") == nil)
    }

    @Test func otherURLsGiveNil() {
        #expect(SafeSearch.enforced("https://github.com/search?q=a") == nil)
        #expect(SafeSearch.enforced("file:///tmp/a.html?q=a") == nil)
        #expect(SafeSearch.enforced("not a url") == nil)
    }

    @Test func trailingDotHostsStillMatch() {
        #expect(SafeSearch.enforced("https://www.bing.com./search?q=a") == "https://www.bing.com./search?q=a&adlt=strict")
        #expect(SafeSearch.enforced("https://duckduckgo.com./?q=a") == "https://duckduckgo.com./?q=a&kp=1")
    }
}
