import Foundation

/// Writes SegmentBuilder events to the store: insert on open, update end at most every
/// `flushInterval` while extending, final update on close, delete on discard.
public final class SegmentRecorder {
    private let store: Store
    private let flushInterval: TimeInterval
    public private(set) var openID: Int64?
    private var lastFlush: Date?

    public init(store: Store, flushInterval: TimeInterval = 30) {
        self.store = store
        self.flushInterval = flushInterval
    }

    @discardableResult
    public func apply(_ events: [SegmentEvent], now: Date) throws -> [Segment] {
        var closed: [Segment] = []
        for event in events {
            switch event {
            case .opened(let s):
                openID = try store.insertSegment(s)
                lastFlush = now
            case .extended(let s):
                if let id = openID, let last = lastFlush, now.timeIntervalSince(last) >= flushInterval {
                    try store.updateSegmentEnd(id: id, end: s.end)
                    lastFlush = now
                }
            case .closed(var s):
                if let id = openID {
                    try store.updateSegmentEnd(id: id, end: s.end)
                    s.id = id
                }
                openID = nil
                lastFlush = nil
                closed.append(s)
            case .discarded:
                if let id = openID { try store.deleteSegment(id: id) }
                openID = nil
                lastFlush = nil
            }
        }
        return closed
    }
}
