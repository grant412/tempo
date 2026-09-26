import Foundation

enum Log {
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Tempo.log")
    private static let formatter = ISO8601DateFormatter()

    static func info(_ message: String) { write("INFO " + message) }
    static func error(_ message: String) { write("ERROR " + message) }

    /// Appends one line. A failed write (disk full, permissions) is dropped: logging never crashes the app.
    private static func write(_ line: String) {
        let data = Data("\(formatter.string(from: Date())) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                return
            }
        } else {
            try? data.write(to: url)
        }
    }
}
