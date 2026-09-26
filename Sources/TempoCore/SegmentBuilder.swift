import Foundation

public enum Presence: Equatable, Sendable {
    /// Someone is at the Mac and this is in front.
    case active(Snapshot)
    /// No input for at least the idle threshold. `lastInput` is when input last happened.
    case idle(lastInput: Date)
    /// Locked, asleep, paused, or screensaver.
    case away
}

public enum SegmentEvent: Equatable, Sendable {
    case opened(Segment)
    case extended(Segment)
    case closed(Segment)
    /// Closed but shorter than one second: delete it.
    case discarded(Segment)
}

public struct SegmentBuilder: Sendable {
    public private(set) var open: Segment?
    private var lastTick: Date?
    public let maxTickGap: TimeInterval

    public init(maxTickGap: TimeInterval = 30) {
        self.maxTickGap = maxTickGap
    }

    public mutating func tick(at now: Date, presence: Presence) -> [SegmentEvent] {
        var events: [SegmentEvent] = []
        if let last = lastTick, now.timeIntervalSince(last) > maxTickGap, open != nil {
            events += close(at: last)
        }
        lastTick = now

        switch presence {
        case .away:
            events += close(at: now)
        case .idle(let lastInput):
            events += close(at: min(lastInput, now))
        case .active(let snapshot):
            if var seg = open,
               seg.snapshot.bundleID == snapshot.bundleID,
               seg.snapshot.domain == snapshot.domain {
                seg.end = now
                if seg.snapshot.title == nil { seg.snapshot.title = snapshot.title }
                open = seg
                events.append(.extended(seg))
            } else {
                events += close(at: now)
                let seg = Segment(id: nil, start: now, end: now, snapshot: snapshot)
                open = seg
                events.append(.opened(seg))
            }
        }
        return events
    }

    private mutating func close(at time: Date) -> [SegmentEvent] {
        guard var seg = open else { return [] }
        open = nil
        seg.end = max(seg.start, time)
        return seg.duration < 1 ? [.discarded(seg)] : [.closed(seg)]
    }
}
