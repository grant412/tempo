import Testing
@testable import TempoCore

struct DisplayWakeTests {
    @Test func leakedAudioAssertionsDoNotHoldPresence() {
        let stuck = (0..<40).map {
            DisplayWakeAssertion(ownerProcess: "coreaudiod",
                                 name: "com.apple.audio.context\($0).preventuseridledisplaysleep")
        }
        #expect(!DisplayWake.holdsPresence(stuck))
        #expect(!DisplayWake.holdsPresence([]))
    }

    @Test func callOrVideoHoldsPresence() {
        let call = DisplayWakeAssertion(ownerProcess: "FaceTime", name: "Ongoing A/V conference")
        let audio = DisplayWakeAssertion(ownerProcess: "coreaudiod", name: "com.apple.audio.context1")
        #expect(DisplayWake.holdsPresence([audio, call]))
    }
}
