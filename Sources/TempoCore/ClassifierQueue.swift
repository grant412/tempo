import Foundation

/// Unknown item keys waiting for Claude, with per-key backoff stored in the database.
public final class ClassifierQueue {
    private let store: Store
    public let maxBatch: Int
    private var order: [ItemKey] = []
    private var items: [ItemKey: ClassifyItem] = [:]

    public init(store: Store, maxBatch: Int = 20) {
        self.store = store
        self.maxBatch = maxBatch
    }

    public var pendingCount: Int { order.count }

    /// 1 h after the first failure, doubling, capped at 24 h.
    public static func backoff(failures: Int) -> TimeInterval {
        min(86_400, 3_600 * pow(2, Double(max(0, failures - 1))))
    }

    @discardableResult
    public func enqueue(_ item: ClassifyItem, resolver: RuleResolver, now: Date) throws -> Bool {
        guard items[item.key] == nil, !resolver.isKnown(item.key) else { return false }
        if let attempt = try store.classifyAttempt(for: item.key),
           now < attempt.lastTry.addingTimeInterval(Self.backoff(failures: attempt.failures)) {
            return false
        }
        items[item.key] = item
        order.append(item.key)
        return true
    }

    public func nextBatch() -> [ClassifyItem] {
        let keys = Array(order.prefix(maxBatch))
        order.removeFirst(keys.count)
        return keys.compactMap { items.removeValue(forKey: $0) }
    }

    /// Saves answers as Claude rules (never overwriting) and records a failure for any key Claude skipped.
    @discardableResult
    public func complete(batch: [ClassifyItem], results: [ItemKey: CategoryID], now: Date) throws -> Int {
        var inserted = 0
        for item in batch {
            if let cat = results[item.key] {
                if try store.insertRuleIfAbsent(item.key, category: cat, source: .claude, at: now) { inserted += 1 }
                try store.clearClassifyAttempt(item.key)
            } else {
                try store.recordClassifyFailure(item.key, at: now)
            }
        }
        return inserted
    }

    public func fail(batch: [ClassifyItem], now: Date) throws {
        for item in batch { try store.recordClassifyFailure(item.key, at: now) }
    }

    /// Puts a batch back at the front without counting a failure (used when the key is rejected).
    public func requeue(_ batch: [ClassifyItem]) {
        for item in batch.reversed() where items[item.key] == nil {
            items[item.key] = item
            order.insert(item.key, at: 0)
        }
    }
}
