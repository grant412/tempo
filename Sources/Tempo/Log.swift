import Foundation

enum Log {
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Tempo.log")

    static func info(_ message: String) { write("INFO " + message) }
    static func error(_ message: String) { write("ERROR " + message) }

    private static func write(_ line: String) {
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
