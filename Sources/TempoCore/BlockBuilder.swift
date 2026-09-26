import Foundation

public struct BlockItem: Equatable, Sendable {
    public let key: ItemKey
    public let displayName: String
    public let category: CategoryID
    public var duration: TimeInterval
}

public struct Block: Equatable, Identifiable, Sendable {
    public var id: Date { start }
    public var start: Date
    public var end: Date
    public var category: CategoryID
    public var isLive: Bool
    /// Sorted by duration, longest first.
    public var items: [BlockItem]

    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var topNames: [String] { items.prefix(3).map(\.displayName) }
}

public struct AwayGap: Equatable, Identifiable, Sendable {
    public var id: Date { start }
    public let start: Date
    public let end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

public struct DayLayout: Equatable, Sendable {
    public let blocks: [Block]
    public let gaps: [AwayGap]
    public static let empty = DayLayout(blocks: [], gaps: [])
}

public enum BlockBuilder {
    public static let joinGap: TimeInterval = 60
    public static let foldMax: TimeInterval = 120
    public static let awayMin: TimeInterval = 300

    struct Run {
        var category: CategoryID
        var start: Date
        var end: Date
        var segments: [Segment]
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    public static func build(segments: [Segment], day: DateInterval, resolver: RuleResolver,
                             openSegmentEnd: Date? = nil) -> DayLayout {
        let clipped = segments.compactMap { $0.clipped(to: day) }.sorted { $0.start < $1.start }

        // 1. Runs of one category with gaps of 60 s or less.
        var runs: [Run] = []
        for seg in clipped {
            let cat = resolver.category(for: seg.itemKey)
            if var last = runs.last, last.category == cat, seg.start.timeIntervalSince(last.end) <= joinGap {
                last.end = max(last.end, seg.end)
                last.segments.append(seg)
                runs[runs.count - 1] = last
            } else {
                runs.append(Run(category: cat, start: seg.start, end: seg.end, segments: [seg]))
            }
        }

        // 2. Fold short runs sandwiched between two runs of the same category.
        var i = 1
        while i < runs.count - 1 {
            let a = runs[i - 1], m = runs[i], b = runs[i + 1]
            if m.duration < foldMax, a.category == b.category,
               m.start.timeIntervalSince(a.end) <= joinGap, b.start.timeIntervalSince(m.end) <= joinGap {
                let merged = Run(category: a.category, start: a.start, end: max(a.end, b.end),
                                 segments: a.segments + m.segments + b.segments)
                runs.replaceSubrange((i - 1)...(i + 1), with: [merged])
                i = max(1, i - 1)
            } else {
                i += 1
            }
        }

        // 3. Blocks with aggregated items.
        var blocks = runs.map {
            Block(start: $0.start, end: $0.end, category: $0.category, isLive: false,
                  items: items(for: $0.segments, resolver: resolver))
        }
        if let openEnd = openSegmentEnd, openEnd >= day.start, openEnd < day.end, let last = blocks.last,
           abs(last.end.timeIntervalSince(openEnd)) < 1 {
            blocks[blocks.count - 1].isLive = true
        }

        // 4. Away gaps.
        let gaps = zip(blocks, blocks.dropFirst()).compactMap { prev, next -> AwayGap? in
            next.start.timeIntervalSince(prev.end) >= awayMin ? AwayGap(start: prev.end, end: next.start) : nil
        }
        return DayLayout(blocks: blocks, gaps: gaps)
    }

    static func items(for segments: [Segment], resolver: RuleResolver) -> [BlockItem] {
        var byKey: [ItemKey: BlockItem] = [:]
        for s in segments {
            let k = s.itemKey
            if byKey[k] == nil {
                byKey[k] = BlockItem(key: k, displayName: s.snapshot.displayName,
                                     category: resolver.category(for: k), duration: 0)
            }
            byKey[k]!.duration += s.duration
        }
        return byKey.values.sorted {
            $0.duration != $1.duration ? $0.duration > $1.duration : $0.displayName < $1.displayName
        }
    }
}
