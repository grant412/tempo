import Foundation

/// Reads the active tab of Chrome or Safari with AppleScript. Only called when one is in front.
@MainActor
final class BrowserTabReader {
    static let shared = BrowserTabReader()

    enum Tab: Equatable {
        case tab(url: String, title: String?)
        case incognito
    }

    private static let sources: [String: String] = [
        "com.google.Chrome": """
        with timeout of 1 second
          tell application id "com.google.Chrome"
            if (count of windows) is 0 then return ""
            set w to front window
            if mode of w is "incognito" then return "INCOGNITO"
            return (URL of active tab of w) & linefeed & (title of active tab of w)
          end tell
        end timeout
        """,
        "com.apple.Safari": """
        with timeout of 1 second
          tell application id "com.apple.Safari"
            if (count of windows) is 0 then return ""
            set t to current tab of front window
            return (URL of t) & linefeed & (name of t)
          end tell
        end timeout
        """,
    ]

    static var supported: Set<String> { Set(sources.keys) }
    private var compiled: [String: NSAppleScript] = [:]

    func read(bundleID: String) -> Tab? {
        guard let source = Self.sources[bundleID] else { return nil }
        let script: NSAppleScript
        if let cached = compiled[bundleID] {
            script = cached
        } else {
            guard let s = NSAppleScript(source: source) else { return nil }
            var compileError: NSDictionary?
            s.compileAndReturnError(&compileError)
            if compileError != nil { return nil }
            compiled[bundleID] = s
            script = s
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        guard let text = result.stringValue, !text.isEmpty else { return nil }
        if text == "INCOGNITO" { return .incognito }
        let lines = text.components(separatedBy: "\n")
        let title = lines.count > 1 ? lines[1...].joined(separator: " ") : nil
        return .tab(url: lines[0], title: title)
    }
}
