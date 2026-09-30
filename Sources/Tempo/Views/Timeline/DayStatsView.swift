import SwiftUI
import TempoCore

struct DayStatsView: View {
    @EnvironmentObject var model: TempoModel

    private var subtitle: String {
        guard let first = model.summary.firstActivity else { return "Nothing tracked yet" }
        if model.isShowingToday, let line = model.keyboardLine { return line }
        return "\(Format.clock(first)) to \(Format.clock(model.summary.lastActivity ?? first))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: model.isShowingToday ? "Today so far" : "At the keyboard")
            Text(Format.duration(model.summary.total)).font(Theme.display(46)).kerning(-1.8)
            Text(subtitle).font(Theme.ui(13)).foregroundStyle(Theme.muted)
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 18) {
                MiniStat(value: Format.duration(model.summary.longestBlock?.duration ?? 0), label: "longest stretch")
                MiniStat(value: Format.duration(model.summary.distraction), label: "distraction")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct MiniStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.display(20)).kerning(-0.4)
            Text(label).font(Theme.ui(12)).foregroundStyle(Theme.muted)
        }
    }
}
