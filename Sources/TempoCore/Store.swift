import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum StoreError: Error, Equatable {
    case open(String)
    case sql(String)
}

public final class Store {
    private var db: OpaquePointer?

    public init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            db = nil
            throw StoreError.open(message)
        }
        try exec("PRAGMA journal_mode=WAL;")
        try migrate()
    }

    deinit { sqlite3_close(db) }

    // MARK: Segments

    public func insertSegment(_ s: Segment) throws -> Int64 {
        try run("INSERT INTO segments(start, end, bundle_id, app_name, title, domain) VALUES(?,?,?,?,?,?)",
                [s.start.timeIntervalSince1970, s.end.timeIntervalSince1970,
                 s.snapshot.bundleID, s.snapshot.appName, s.snapshot.title, s.snapshot.domain])
        return sqlite3_last_insert_rowid(db)
    }

    public func updateSegmentEnd(id: Int64, end: Date) throws {
        try run("UPDATE segments SET end = ? WHERE id = ?", [end.timeIntervalSince1970, id])
    }

    public func deleteSegment(id: Int64) throws {
        try run("DELETE FROM segments WHERE id = ?", [id])
    }

    public func segments(overlapping interval: DateInterval) throws -> [Segment] {
        let start = interval.start.timeIntervalSince1970
        let end = interval.end.timeIntervalSince1970
        return try query("""
            SELECT id, start, end, bundle_id, app_name, title, domain FROM segments
            WHERE start < ? AND end > ? AND start > ? ORDER BY start
            """, [end, start, start - 172_800]) { s in
            Segment(id: s.int(0),
                    start: Date(timeIntervalSince1970: s.double(1)),
                    end: Date(timeIntervalSince1970: s.double(2)),
                    snapshot: Snapshot(bundleID: s.text(3) ?? "", appName: s.text(4) ?? "",
                                       title: s.text(5), domain: s.text(6)))
        }
    }

    // MARK: Rules

    public func allRules() throws -> [Rule] {
        try query("SELECT kind, key, category_id, source, updated_at FROM rules ORDER BY kind, key") { s in
            Rule(key: ItemKey(kind: RuleKind(rawValue: s.text(0) ?? "app") ?? .app, key: s.text(1) ?? ""),
                 category: s.text(2).flatMap(CategoryID.init(rawValue:)),
                 source: RuleSource(rawValue: s.text(3) ?? "default") ?? .defaultRule,
                 updatedAt: Date(timeIntervalSince1970: s.double(4)))
        }
    }

    public func setUserRule(_ key: ItemKey, category: CategoryID, at: Date) throws {
        try upsertUser(key, category: category.rawValue, at: at)
    }

    /// Inserts only when no row exists for (kind, key). Returns true if a row was inserted.
    @discardableResult
    public func insertRuleIfAbsent(_ key: ItemKey, category: CategoryID, source: RuleSource, at: Date) throws -> Bool {
        try run("INSERT OR IGNORE INTO rules(kind, key, category_id, source, updated_at) VALUES(?,?,?,?,?)",
                [key.kind.rawValue, key.key, category.rawValue, source.rawValue, at.timeIntervalSince1970])
        return sqlite3_changes(db) > 0
    }

    /// Stores a tombstone so seeds and Claude never bring the rule back.
    public func deleteRule(_ key: ItemKey, at: Date) throws {
        try upsertUser(key, category: nil, at: at)
    }

    private func upsertUser(_ key: ItemKey, category: String?, at: Date) throws {
        try run("""
            INSERT INTO rules(kind, key, category_id, source, updated_at) VALUES(?,?,?,'user',?)
            ON CONFLICT(kind, key) DO UPDATE SET category_id = excluded.category_id,
              source = 'user', updated_at = excluded.updated_at
            """, [key.kind.rawValue, key.key, category, at.timeIntervalSince1970])
    }

    // MARK: Nudges

    @discardableResult
    public func logNudge(_ kind: NudgeKind, at: Date) throws -> Int64 {
        try run("INSERT INTO nudges(at, kind) VALUES(?, ?)", [at.timeIntervalSince1970, kind.rawValue])
        return sqlite3_last_insert_rowid(db)
    }

    public func nudges(in interval: DateInterval) throws -> [NudgeRecord] {
        try query("SELECT id, at, kind FROM nudges WHERE at >= ? AND at < ? ORDER BY at",
                  [interval.start.timeIntervalSince1970, interval.end.timeIntervalSince1970]) { s in
            NudgeRecord(id: s.int(0), at: Date(timeIntervalSince1970: s.double(1)),
                        kind: NudgeKind(rawValue: s.text(2) ?? "break") ?? .breakTime)
        }
    }

    // MARK: Classify attempts

    public func classifyAttempt(for key: ItemKey) throws -> ClassifyAttempt? {
        try query("SELECT last_try, failures FROM classify_attempts WHERE kind = ? AND key = ?",
                  [key.kind.rawValue, key.key]) { s in
            ClassifyAttempt(lastTry: Date(timeIntervalSince1970: s.double(0)), failures: Int(s.int(1)))
        }.first
    }

    public func recordClassifyFailure(_ key: ItemKey, at: Date) throws {
        try run("""
            INSERT INTO classify_attempts(kind, key, last_try, failures) VALUES(?,?,?,1)
            ON CONFLICT(kind, key) DO UPDATE SET last_try = excluded.last_try, failures = failures + 1
            """, [key.kind.rawValue, key.key, at.timeIntervalSince1970])
    }

    public func clearClassifyAttempt(_ key: ItemKey) throws {
        try run("DELETE FROM classify_attempts WHERE kind = ? AND key = ?", [key.kind.rawValue, key.key])
    }

    // MARK: Meta

    public func meta(_ key: String) throws -> String? {
        try query("SELECT value FROM meta WHERE key = ?", [key]) { $0.text(0) }.first ?? nil
    }

    public func setMeta(_ key: String, _ value: String) throws {
        try run("INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)", [key, value])
    }

    // MARK: Schema

    private func migrate() throws {
        try exec("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);")
        let version = Int(try meta("schema_version") ?? "0") ?? 0
        if version < 1 {
            try exec("""
                BEGIN;
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
                INSERT OR REPLACE INTO meta(key, value) VALUES('schema_version', '1');
                COMMIT;
                """)
        }
    }

    // MARK: SQLite helpers

    final class Statement {
        let handle: OpaquePointer

        init(db: OpaquePointer?, sql: String) throws {
            var s: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK, let s else {
                throw StoreError.sql(String(cString: sqlite3_errmsg(db)))
            }
            handle = s
        }

        deinit { sqlite3_finalize(handle) }

        func bind(_ values: [Any?]) throws {
            for (i, value) in values.enumerated() {
                let idx = Int32(i + 1)
                guard let value else {
                    sqlite3_bind_null(handle, idx)
                    continue
                }
                switch value {
                case let v as Double: sqlite3_bind_double(handle, idx, v)
                case let v as Int64: sqlite3_bind_int64(handle, idx, v)
                case let v as Int: sqlite3_bind_int64(handle, idx, Int64(v))
                case let v as String: sqlite3_bind_text(handle, idx, v, -1, SQLITE_TRANSIENT)
                default: throw StoreError.sql("unsupported bind type at \(idx)")
                }
            }
        }

        func double(_ c: Int32) -> Double { sqlite3_column_double(handle, c) }
        func int(_ c: Int32) -> Int64 { sqlite3_column_int64(handle, c) }
        func text(_ c: Int32) -> String? {
            guard let p = sqlite3_column_text(handle, c) else { return nil }
            return String(cString: p)
        }
    }

    func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(err)
            throw StoreError.sql(message)
        }
    }

    func run(_ sql: String, _ values: [Any?] = []) throws {
        let s = try Statement(db: db, sql: sql)
        try s.bind(values)
        let rc = sqlite3_step(s.handle)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw StoreError.sql(String(cString: sqlite3_errmsg(db)))
        }
    }

    func query<T>(_ sql: String, _ values: [Any?] = [], _ row: (Statement) -> T) throws -> [T] {
        let s = try Statement(db: db, sql: sql)
        try s.bind(values)
        var out: [T] = []
        while true {
            let rc = sqlite3_step(s.handle)
            if rc == SQLITE_ROW { out.append(row(s)) }
            else if rc == SQLITE_DONE { break }
            else { throw StoreError.sql(String(cString: sqlite3_errmsg(db))) }
        }
        return out
    }
}
