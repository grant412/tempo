import Foundation
import Testing
@testable import TempoCore

private typealias F = Fixtures

struct BlockBuilderTests {
    @Test func wednesdayMakesThirteenBlocksAndTwoGaps() {
        let layout = BlockBuilder.build(segments: F.wednesday, day: F.day, resolver: F.resolver)
        #expect(layout.blocks.count == 13)
        #expect(layout.blocks.map(\.category) == [.comms, .distraction, .code, .meet, .code, .research, .admin,
                                                  .distraction, .design, .writing, .uncategorized, .code, .comms])
        #expect(layout.gaps.map { $0.duration / 60 } == [5, 43])
        #expect(layout.blocks[4].duration == 112 * 60)
    }

    @Test func sameCategoryWithinSixtySecondsJoins() {
        let segs = [F.seg(600, 610, F.terminal),
                    Segment(id: nil, start: F.at(610).addingTimeInterval(30), end: F.at(620), snapshot: F.terminal)]
        let layout = BlockBuilder.build(segments: segs, day: F.day, resolver: F.resolver)
        #expect(layout.blocks.count == 1)
        #expect(layout.blocks[0].items.count == 1)
        #expect(layout.blocks[0].items[0].duration == 19.5 * 60)
    }

    @Test func shortSandwichedSwitchFolds() {
        let segs = [F.seg(600, 610, F.terminal),
                    Segment(id: nil, start: F.at(610), end: F.at(610).addingTimeInterval(60), snapshot: F.messages),
                    Segment(id: nil, start: F.at(610).addingTimeInterval(60), end: F.at(620), snapshot: F.terminal)]
        let layout = BlockBuilder.build(segments: segs, day: F.day, resolver: F.resolver)
        #expect(layout.blocks.count == 1)
        #expect(layout.blocks[0].category == .code)
        #expect(layout.blocks[0].items.map(\.displayName) == ["Terminal", "Messages"])
        #expect(layout.blocks[0].items[1].category == .comms)
    }

    @Test func twoMinuteSwitchDoesNotFold() {
        let segs = [F.seg(600, 610, F.terminal), F.seg(610, 612, F.messages), F.seg(612, 620, F.terminal)]
        let layout = BlockBuilder.build(segments: segs, day: F.day, resolver: F.resolver)
        #expect(layout.blocks.map(\.category) == [.code, .comms, .code])
    }

    @Test func clipsToTheDay() {
        let late = Segment(id: nil, start: F.at(23 * 60 + 50), end: F.at(24 * 60 + 20), snapshot: F.terminal)
        let layout = BlockBuilder.build(segments: [late], day: F.day, resolver: F.resolver)
        #expect(layout.blocks.count == 1)
        #expect(layout.blocks[0].duration == 10 * 60)
    }

    @Test func liveFlagMarksTheBlockEndingAtTheOpenSegment() {
        let segs = [F.seg(600, 620, F.terminal), F.seg(620, 641, F.youtube)]
        let layout = BlockBuilder.build(segments: segs, day: F.day, resolver: F.resolver, openSegmentEnd: F.at(641))
        #expect(layout.blocks.last?.isLive == true)
        #expect(layout.blocks.first?.isLive == false)
    }
}
