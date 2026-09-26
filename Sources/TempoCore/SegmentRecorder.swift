import Foundation

/// Writes SegmentBuilder events to the store: insert on open, update end at most every
/// `flushInterval` while extending, final update on close, delete on discard.
///
/// A failed write never stops the rest of a batch: every event is applied, then the first
/// error is rethrown. A segment whose insert failed stays pending in memory and the insert
/// is retried on its next event.
public final class SegmentRecorder {
    private let store: Store
    private let flushInterval: TimeInterval
    public private(set) var openID: Int64?
    private var lastFlush: Date?
    /// The open segment while its insert has not succeeded yet.
    private var pending: Segment?

    /// `flushInterval` defaults to 24 s, which keeps the worst case gap between writes of
    /// `end` at 30 s with 5 s ticks and 1 s timer tolerance.
    public init(store: Store, flushInterval: TimeInterval = 24) {
        self.store = store
        self.flushInterval = flushInterval
    }

    @discardableResult
    public func apply(_ events: [SegmentEvent], now: Date) throws -> [Segment] {
        var closed: [Segment] = []
        var firstError: Error?
        for event in events {
            do {
                if let segment = try record(event, now: now) { closed.append(segment) }
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
        return closed
    }

    /// Applies one event. Recorder state is settled before any store call, so a throw leaves
    /// it pointing at the right segment. Returns the segment when the event closes one.
    private func record(_ event: SegmentEvent, now: Date) throws -> Segment? {
        switch event {
        case .opened(let s):
            openID = nil
            lastFlush = nil
            pending = s
            try insertPending(now: now)
        case .extended(let s):
            if pending != nil {
                pending = s
                try insertPending(now: now)
            } else if let id = openID, let last = lastFlush, now.timeIntervalSince(last) >= flushInterval {
                try store.updateSegmentEnd(id: id, end: s.end)
                lastFlush = now
            }
        case .closed(var s):
            let id = openID
            let wasPending = pending != nil
            openID = nil
            lastFlush = nil
            pending = nil
            if let id {
                s.id = id
                try store.updateSegmentEnd(id: id, end: s.end)
            } else if wasPending {
                s.id = try store.insertSegment(s)
            }
            return s
        case .discarded:
            let id = openID
            openID = nil
            lastFlush = nil
            pending = nil
            if let id { try store.deleteSegment(id: id) }
        }
        return nil
    }

    private func insertPending(now: Date) throws {
        guard let s = pending else { return }
        openID = try store.insertSegment(s)
        pending = nil
        lastFlush = now
    }
}
