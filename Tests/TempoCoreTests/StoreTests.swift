import Foundation
import SQLite3
import Testing
@testable import TempoCore

private func d(_ s: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + s) }
private let term = Snapshot(bundleID: "com.apple.Terminal", appName: "Terminal", title: "zsh", domain: nil)
private let yt = Snapshot(bundleID: "com.google.Chrome", appName: "Google Chrome", title: "Video", domain: "youtube.com")

struct StoreTests {
    @Test func migratesFreshDatabase() throws {
        let store = try Store(path: ":memory:")
        #expect(try store.meta("schema_version") == "2")
    }

    @Test func segmentInsertUpdateQueryDelete() throws {
        let store = try Store(path: ":memory:")
        let id = try store.insertSegment(Segment(id: nil, start: d(0), end: d(0), snapshot: term))
        try store.updateSegmentEnd(id: id, end: d(120))
        _ = try store.insertSegment(Segment(id: nil, start: d(200), end: d(260), snapshot: yt))
        let all = try store.segments(overlapping: DateInterval(start: d(0), end: d(1000)))
        #expect(all.count == 2)
        #expect(all[0] == Segment(id: id, start: d(0), end: d(120), snapshot: term))
        #expect(all[1].snapshot.domain == "youtube.com")
        let later = try store.segments(overlapping: DateInterval(start: d(130), end: d(1000)))
        #expect(later.count == 1)
        try store.deleteSegment(id: id)
        #expect(try store.segments(overlapping: DateInterval(start: d(0), end: d(1000))).count == 1)
    }

    @Test func userRulesOverwriteAndOthersOnlyInsert() throws {
        let store = try Store(path: ":memory:")
        let key = ItemKey(kind: .domain, key: "github.com")
        #expect(try store.insertRuleIfAbsent(key, category: .research, source: .claude, at: d(0)))
        #expect(try store.insertRuleIfAbsent(key, category: .admin, source: .defaultRule, at: d(1)) == false)
        try store.setUserRule(key, category: .code, at: d(2))
        #expect(try store.insertRuleIfAbsent(key, category: .admin, source: .claude, at: d(3)) == false)
        let rules = try store.allRules()
        #expect(rules == [Rule(key: key, category: .code, source: .user, updatedAt: d(2))])
    }

    @Test func deleteWritesTombstone() throws {
        let store = try Store(path: ":memory:")
        let key = ItemKey(kind: .app, key: "com.spotify.client")
        _ = try store.insertRuleIfAbsent(key, category: .distraction, source: .defaultRule, at: d(0))
        try store.deleteRule(key, at: d(5))
        #expect(try store.allRules() == [Rule(key: key, category: nil, source: .user, updatedAt: d(5))])
        #expect(try store.insertRuleIfAbsent(key, category: .distraction, source: .defaultRule, at: d(6)) == false)
    }

    @Test func nudgesAndAttemptsAndMeta() throws {
        let store = try Store(path: ":memory:")
        _ = try store.logNudge(.breakTime, at: d(10))
        _ = try store.logNudge(.distraction, at: d(5000))
        let n = try store.nudges(in: DateInterval(start: d(0), end: d(100)))
        #expect(n.map(\.kind) == [.breakTime])

        let key = ItemKey(kind: .domain, key: "example.com")
        #expect(try store.classifyAttempt(for: key) == nil)
        try store.recordClassifyFailure(key, at: d(1))
        try store.recordClassifyFailure(key, at: d(2))
        #expect(try store.classifyAttempt(for: key) == ClassifyAttempt(lastTry: d(2), failures: 2))
        try store.clearClassifyAttempt(key)
        #expect(try store.classifyAttempt(for: key) == nil)

        try store.setMeta("seed_version", "1")
        #expect(try store.meta("seed_version") == "1")
    }

    /// Another program holding a write lock for a moment must not fail a write (spec 12).
    @Test func writeWaitsOutAnotherConnectionsLock() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("tempo-busy-\(UUID().uuidString).db").path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        let store = try Store(path: path)
        var other: OpaquePointer?
        #expect(sqlite3_open(path, &other) == SQLITE_OK)
        #expect(sqlite3_exec(other, "BEGIN IMMEDIATE;", nil, nil, nil) == SQLITE_OK)
        let handle = other
        let released = DispatchSemaphore(value: 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            sqlite3_exec(handle, "COMMIT;", nil, nil, nil)
            released.signal()
        }
        let insert = Result { try store.insertSegment(Segment(id: nil, start: d(0), end: d(60), snapshot: term)) }
        released.wait()
        sqlite3_close(other)
        _ = try insert.get()
        #expect(try store.segments(overlapping: DateInterval(start: d(0), end: d(100))).count == 1)
    }

    /// A segment written through the WAL survives closing and reopening an on-disk database.
    @Test func reopensOnDiskDatabase() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tempo-reopen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("tempo.db").path
        var store: Store? = try Store(path: path)
        let id = try #require(store).insertSegment(Segment(id: nil, start: d(0), end: d(90), snapshot: term))
        #expect(FileManager.default.fileExists(atPath: path + "-wal"))
        store = nil
        let reopened = try Store(path: path)
        #expect(try reopened.meta("schema_version") == "2")
        #expect(try reopened.segments(overlapping: DateInterval(start: d(0), end: d(100)))
            == [Segment(id: id, start: d(0), end: d(90), snapshot: term)])
    }

    /// Only a file that is not a database (or is corrupt) may be moved aside (spec 12).
    @Test func garbageFileFailsWithNotADatabase() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("tempo-garbage-\(UUID().uuidString).db").path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        try Data(String(repeating: "not a database ", count: 300).utf8).write(to: URL(fileURLWithPath: path))
        let error = #expect(throws: StoreError.self) { _ = try Store(path: path) }
        guard case .open(_, let code)? = error else {
            Issue.record("expected StoreError.open, got \(String(describing: error))")
            return
        }
        #expect(code == SQLITE_NOTADB)
        #expect(error?.isUnreadableDatabase == true)
    }

    @Test func missingFolderIsNotShelvable() throws {
        let path = "/tempo-missing-\(UUID().uuidString)/tempo.db"
        let error = #expect(throws: StoreError.self) { _ = try Store(path: path) }
        guard case .open(_, let code)? = error else {
            Issue.record("expected StoreError.open, got \(String(describing: error))")
            return
        }
        #expect(code == SQLITE_CANTOPEN)
        #expect(error?.isUnreadableDatabase == false)
    }

    @Test func focusSessionsInsertNoteAndOverlap() throws {
        let store = try Store(path: ":memory:")
        let a = try store.insertFocusSession(start: d(0), end: d(1500), planned: 1500)
        let b = try store.insertFocusSession(start: d(5000), end: d(5600), planned: 900)
        try store.setFocusNote(id: a, note: "  Shipped the timer \n")
        try store.setFocusNote(id: b, note: "   \n ")
        #expect(try store.focusSession(id: a)
            == FocusSession(id: a, start: d(0), end: d(1500), planned: 1500, note: "Shipped the timer"))
        #expect(try store.focusSession(id: b)?.note == nil)
        #expect(try store.focusSession(id: 999) == nil)
        #expect(try store.focusSessions(overlapping: DateInterval(start: d(1000), end: d(2000))).map(\.id) == [a])
        #expect(try store.focusSessions(overlapping: DateInterval(start: d(0), end: d(9000))).map(\.id) == [a, b])
        #expect(try store.focusSessions(overlapping: DateInterval(start: d(1500), end: d(4999))).isEmpty)
        try store.setFocusNote(id: a, note: nil)
        #expect(try store.focusSession(id: a)?.note == nil)
    }

    /// A database from v1 (no focus_sessions) upgrades in place and keeps its rows.
    @Test func upgradesVersionOneDatabase() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("tempo-v1-\(UUID().uuidString).db").path
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var raw: OpaquePointer?
        #expect(sqlite3_open(path, &raw) == SQLITE_OK)
        let v1 = """
            CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE segments(
              id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL,
              bundle_id TEXT NOT NULL, app_name TEXT NOT NULL, title TEXT, domain TEXT);
            CREATE INDEX segments_start ON segments(start);
            CREATE TABLE rules(
              kind TEXT NOT NULL CHECK(kind IN ('app','domain')), key TEXT NOT NULL,
              category_id TEXT, source TEXT NOT NULL CHECK(source IN ('default','user','claude')),
              updated_at REAL NOT NULL, PRIMARY KEY(kind, key));
            CREATE TABLE nudges(id INTEGER PRIMARY KEY, at REAL NOT NULL,
              kind TEXT NOT NULL CHECK(kind IN ('break','distraction')));
            CREATE TABLE classify_attempts(kind TEXT NOT NULL, key TEXT NOT NULL,
              last_try REAL NOT NULL, failures INTEGER NOT NULL, PRIMARY KEY(kind, key));
            INSERT INTO meta(key, value) VALUES('schema_version', '1');
            INSERT INTO segments(start, end, bundle_id, app_name, title, domain)
              VALUES(1000000, 1000090, 'com.apple.Terminal', 'Terminal', 'zsh', NULL);
            """
        #expect(sqlite3_exec(raw, v1, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(raw)

        let store = try Store(path: path)
        #expect(try store.meta("schema_version") == "2")
        #expect(try store.segments(overlapping: DateInterval(start: d(0), end: d(100)))
            == [Segment(id: 1, start: d(0), end: d(90), snapshot: term)])
        let id = try store.insertFocusSession(start: d(0), end: d(1500), planned: 1500)
        #expect(try store.focusSession(id: id)?.planned == 1500)
    }
}
