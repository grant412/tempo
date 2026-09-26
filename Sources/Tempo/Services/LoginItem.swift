import Foundation
import TempoCore

/// Open at login via a LaunchAgent (spec section 10).
enum LoginItem {
    static var isEnabled: Bool { FileManager.default.fileExists(atPath: LaunchAgent.defaultPlistURL.path) }

    static func writePlist() throws {
        let url = LaunchAgent.defaultPlistURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try LaunchAgent.plistData(executablePath: LaunchAgent.appExecutable).write(to: url, options: .atomic)
    }

    /// Writes the plist and loads it. If Tempo is already running outside launchd, the copy
    /// launchd starts exits at once (single instance), and crash restart applies from next login.
    static func enable() throws {
        try writePlist()
        launchctl(["bootstrap", "gui/\(getuid())", LaunchAgent.defaultPlistURL.path])
    }

    /// Removes the plist so Tempo will not start at next login. Does not stop the running copy.
    static func disable() throws {
        if isEnabled { try FileManager.default.removeItem(at: LaunchAgent.defaultPlistURL) }
    }

    private static func launchctl(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
