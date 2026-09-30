import AppKit

/// Reads and sets tab URLs in Chrome and Safari for site blocking (site blocking spec 5.2).
/// Unlike the tracker's `BrowserTabReader` it sees every tab, incognito and private ones
/// included; nothing read here is stored. Callers check that the browser is running first,
/// because a `tell` would launch it.
@MainActor
final class BrowserTabs {
    struct TabRef: Hashable {
        let bundleID: String
        /// The browser's window id.
        let window: Int
        /// 1-based tab index in that window. Read and write happen in the same tick.
        let tab: Int
    }

    struct Tab {
        let ref: TabRef
        let url: String
    }

    static let chrome = "com.google.Chrome"
    static let safari = "com.apple.Safari"
    static let supported: Set<String> = [chrome, safari]

    /// Each script returns one line per tab: window id, tab index, URL, joined by a tab
    /// character. `sep` is set outside the `tell` because `tab` names a tab object inside it.
    private static let frontSources: [String: String] = [
        chrome: """
        set sep to character id 9
        with timeout of 1 second
          tell application id "com.google.Chrome"
            if (count of windows) is 0 then return ""
            set w to front window
            return ((id of w) as text) & sep & ((active tab index of w) as text) & sep & (URL of active tab of w)
          end tell
        end timeout
        """,
        safari: """
        set sep to character id 9
        with timeout of 1 second
          tell application id "com.apple.Safari"
            if (count of windows) is 0 then return ""
            set w to front window
            set t to current tab of w
            set u to URL of t
            if u is missing value then return ""
            return ((id of w) as text) & sep & ((index of t) as text) & sep & u
          end tell
        end timeout
        """,
    ]

    /// Two Apple Events per window (URLs in bulk), not one per tab. A window that errors is skipped.
    private static let allSources: [String: String] = [
        chrome: """
        set sep to character id 9
        set out to ""
        with timeout of 1 second
          tell application id "com.google.Chrome"
            repeat with w in windows
              try
                set wid to id of w
                set urls to URL of every tab of w
                repeat with i from 1 to count of urls
                  set out to out & (wid as text) & sep & (i as text) & sep & (item i of urls) & linefeed
                end repeat
              end try
            end repeat
          end tell
        end timeout
        return out
        """,
        safari: """
        set sep to character id 9
        set out to ""
        with timeout of 1 second
          tell application id "com.apple.Safari"
            repeat with w in windows
              try
                set wid to id of w
                set urls to URL of every tab of w
                repeat with i from 1 to count of urls
                  set u to item i of urls
                  if u is not missing value then
                    set out to out & (wid as text) & sep & (i as text) & sep & u & linefeed
                  end if
                end repeat
              end try
            end repeat
          end tell
        end timeout
        return out
        """,
    ]

    private var compiled: [String: NSAppleScript] = [:]

    func frontTab(bundleID: String) -> Tab? {
        guard let source = Self.frontSources[bundleID],
              let text = run("front " + bundleID, source) else { return nil }
        return parse(text, bundleID: bundleID).first
    }

    /// nil when the read failed (Automation denied, timeout); empty when there are no tabs.
    func allTabs(bundleID: String) -> [Tab]? {
        guard let source = Self.allSources[bundleID],
              let text = run("all " + bundleID, source) else { return nil }
        return parse(text, bundleID: bundleID)
    }

    @discardableResult
    func setURL(_ url: String, at ref: TabRef) -> Bool {
        guard Self.supported.contains(ref.bundleID) else { return false }
        let quoted = "\"" + url.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
        let source = """
        with timeout of 1 second
          tell application id "\(ref.bundleID)"
            set URL of tab \(ref.tab) of window id \(ref.window) to \(quoted)
          end tell
        end timeout
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    private func run(_ key: String, _ source: String) -> String? {
        let script: NSAppleScript
        if let cached = compiled[key] {
            script = cached
        } else {
            guard let s = NSAppleScript(source: source) else { return nil }
            var compileError: NSDictionary?
            s.compileAndReturnError(&compileError)
            if compileError != nil { return nil }
            compiled[key] = s
            script = s
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue ?? ""
    }

    private func parse(_ text: String, bundleID: String) -> [Tab] {
        text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard f.count == 3, let w = Int(f[0]), let t = Int(f[1]), !f[2].isEmpty else { return nil }
            return Tab(ref: TabRef(bundleID: bundleID, window: w, tab: t), url: String(f[2]))
        }
    }
}
