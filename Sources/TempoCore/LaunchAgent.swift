import Foundation

public enum LaunchAgent {
    public static let label = "com.grantfeltz.tempo"
    public static let appExecutable = "/Applications/Tempo.app/Contents/MacOS/Tempo"

    public static var defaultPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Starts at login, relaunches after a crash (non-zero exit), stays quit after Quit (exit 0).
    public static func plistData(executablePath: String) throws -> Data {
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive",
            "ThrottleInterval": 10,
        ]
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }
}
