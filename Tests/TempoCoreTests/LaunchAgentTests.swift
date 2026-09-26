import Foundation
import Testing
@testable import TempoCore

struct LaunchAgentTests {
    @Test func plistRestartsOnCrashOnly() throws {
        let data = try LaunchAgent.plistData(executablePath: LaunchAgent.appExecutable)
        let dict = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(dict["Label"] as? String == "com.grantfeltz.tempo")
        #expect(dict["ProgramArguments"] as? [String] == ["/Applications/Tempo.app/Contents/MacOS/Tempo"])
        #expect(dict["RunAtLoad"] as? Bool == true)
        #expect((dict["KeepAlive"] as? [String: Any])?["SuccessfulExit"] as? Bool == false)
        #expect(dict["ProcessType"] as? String == "Interactive")
        #expect(dict["ThrottleInterval"] as? Int == 10)
        #expect(LaunchAgent.defaultPlistURL.path.hasSuffix("Library/LaunchAgents/com.grantfeltz.tempo.plist"))
    }
}
