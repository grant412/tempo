import SwiftUI
import TempoCore

struct DayCanvasView: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Timeline").font(Theme.display(20)).kerning(-0.4)
                Spacer()
                // Narrow windows drop the hint sentence rather than wrap it.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Text("Click any block to see what was inside.").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                        legend
                    }
                    legend
                }
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    DayCanvas(range: model.visibleRange, layout: model.layout, nudges: model.nudgeMarks,
                              focus: model.focusSessions,
                              now: model.isShowingToday ? model.now : nil, selectedID: model.selectedBlockID,
                              calendar: model.calendar) { model.select($0) }
                        .padding(.vertical, 10)
                        .padding(.trailing, 14)
                }
                .onAppear { proxy.scrollTo(DayCanvas.anchorID, anchor: .center) }
                .onChange(of: model.shownDay) { _, _ in proxy.scrollTo(DayCanvas.anchorID, anchor: .center) }
                .onChange(of: model.scrollRequest) { _, _ in proxy.scrollTo(DayCanvas.anchorID, anchor: .center) }
            }
        }
        .card(EdgeInsets(top: 14, leading: 18, bottom: 12, trailing: 18))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                FocusBadge(size: 18)
                Text("focus timer").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                NudgeBadge(size: 18)
                Text("nudge sent").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct DayCanvas: View {
    static let anchorID = "day-anchor"

    let range: DateInterval
    let layout: DayLayout
    let nudges: [NudgeRecord]
    let focus: [FocusSession]
    let now: Date?
    let selectedID: Date?
    let calendar: Calendar
    let onSelect: (Block) -> Void

    private let gutter: CGFloat = 64
    /// Left edge of a focus band; the bar sits at x 58 to 61, just left of the block column.
    private let bandX: CGFloat = 51.5
    private func y(_ d: Date) -> CGFloat { CGFloat(d.timeIntervalSince(range.start) / 60) }
    private var height: CGFloat { CGFloat(range.duration / 60) }
    private var hours: [Date] { stride(from: 0, through: range.duration, by: 3600).map { range.start.addingTimeInterval($0) } }
    private var anchorY: CGFloat { now.map(y) ?? y(layout.blocks.first?.start ?? range.start) }

    var body: some View {
        GeometryReader { geo in
            let width = max(0, geo.size.width - gutter)
            ZStack(alignment: .topLeading) {
                ForEach(hours, id: \.self) { h in
                    Text(Format.hourLabel(calendar.component(.hour, from: h)))
                        .font(Theme.mono(11)).foregroundStyle(Theme.muted)
                        .frame(width: 50, alignment: .trailing)
                        .offset(y: y(h) - 7)
                    Rectangle().fill(Theme.grid).frame(width: max(0, geo.size.width - 58), height: 1)
                        .offset(x: 58, y: y(h))
                    if h.addingTimeInterval(1800) < range.end {
                        Path { p in
                            p.move(to: .zero)
                            p.addLine(to: CGPoint(x: width, y: 0))
                        }
                        .stroke(Theme.grid2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: width, height: 1)
                        .offset(x: gutter, y: y(h) + 30)
                    }
                }

                ForEach(layout.gaps) { gap in
                    let span = y(gap.end) - y(gap.start)
                    AwayView(duration: gap.duration, span: span)
                        .frame(width: width, height: max(0, span - 2))
                        .offset(x: gutter, y: y(gap.start))
                }

                ForEach(layout.blocks) { block in
                    let h = max(2, y(block.end) - y(block.start) - 2)
                    BlockView(block: block, height: h, selected: block.id == selectedID)
                        .frame(width: width, height: h)
                        .offset(x: gutter, y: y(block.start))
                        .onTapGesture { onSelect(block) }
                        .zIndex(block.id == selectedID ? 1 : 0) // keep the ring above the next block
                }

                ForEach(nudges) { n in
                    NudgeBadge(size: 24)
                        .help(n.kind == .breakTime ? "Break nudge at \(Format.clock(n.at))" : "Distraction nudge at \(Format.clock(n.at))")
                        .offset(x: geo.size.width - 12, y: y(n.at) - 12)
                        .zIndex(2)
                }

                ForEach(focus) { s in
                    let top = y(max(s.start, range.start))
                    let bottom = y(min(s.end, range.end))
                    if bottom > top {
                        // Clickable up to x 63, so the blocks from the gutter (x 64) keep their clicks.
                        FocusBand(height: bottom - top, hitWidth: gutter - 1 - bandX)
                            .help(s.note ?? "Focus timer, \(Format.minutesLabel(s.planned)), no notes yet")
                            .onTapGesture { WindowManager.shared.showFocusNotes(sessionID: s.id) }
                            // Bar centered at x 59.5 (the grid line starts at 58); badge centered on its top.
                            .offset(x: bandX, y: top - 8)
                            .zIndex(2)
                    }
                }

                if let now {
                    NowMarker(time: now, width: geo.size.width).offset(y: y(now) - 9).zIndex(2)
                }
            }
        }
        .frame(height: height)
        .overlay {
            // Outside the GeometryReader: inside it, scrollTo centers the whole canvas instead of this point.
            Color.clear.frame(width: 1, height: 1).id(Self.anchorID).position(x: 1, y: anchorY)
        }
    }
}

struct AwayView: View {
    let duration: TimeInterval
    /// The gap's full height in points; the label shows from 24 pt (the drawn section is 2 pt shorter).
    let span: CGFloat
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                var x = -size.height
                while x < size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    ctx.stroke(p, with: .color(Theme.hatch), lineWidth: 5)
                    x += 10
                }
            }
            if span >= 24 {
                Text("Away, \(Format.duration(duration))").font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct NudgeBadge: View {
    var size: CGFloat = 24
    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Theme.panel)
            .frame(width: size, height: size)
            .background(Theme.ink, in: Circle())
            .overlay(Circle().stroke(Theme.panel, lineWidth: 2))
    }
}

/// A focus session: a 3 pt ink bar down the gutter with a clock badge on its top.
struct FocusBand: View {
    let height: CGFloat
    /// How much of the 16 pt width, from the left, takes clicks. The badge's right edge overlaps
    /// the block column, so the canvas passes less than 16.
    let hitWidth: CGFloat
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Theme.ink).frame(width: 3, height: height).offset(y: 8)
            FocusBadge(size: 16)
        }
        .frame(width: 16, height: height + 8, alignment: .top)
        .contentShape(Rectangle().size(width: hitWidth, height: height + 8))
    }
}

struct FocusBadge: View {
    var size: CGFloat = 16
    var body: some View {
        Image(systemName: "timer")
            .font(.system(size: size * 0.55, weight: .bold))
            .foregroundStyle(Theme.panel)
            .frame(width: size, height: size)
            .background(Theme.ink, in: Circle())
            .overlay(Circle().stroke(Theme.panel, lineWidth: 1.5))
    }
}

struct NowMarker: View {
    let time: Date
    let width: CGFloat
    private var label: String {
        Format.clock(time).replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: "")
    }
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Theme.ink).frame(width: max(0, width - 58), height: 2).offset(x: 58)
            Circle().fill(Theme.ink).frame(width: 10, height: 10).offset(x: 54)
            Text(label).font(Theme.mono(11, .semibold)).foregroundStyle(Theme.panel)
                .frame(width: 44, height: 18).background(Theme.ink, in: Capsule()).offset(x: 4)
        }
        .frame(width: width, height: 18, alignment: .leading)
        .allowsHitTesting(false)
    }
}
