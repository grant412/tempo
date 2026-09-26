import AppKit
import SwiftUI
import TempoCore

struct MenuBarView: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Today so far")
                Text(Format.duration(model.today.total)).font(Theme.display(46)).kerning(-1.6)
                if let first = model.today.firstActivity {
                    Text("at the keyboard since \(Format.clock(first))").font(Theme.ui(13)).foregroundStyle(Theme.muted)
                }
            }

            if let live = model.liveBlock, !model.isPaused {
                Button { WindowManager.shared.showTimeline() } label: { LiveBlockCard(block: live) }
                    .buttonStyle(.plain)
            }

            if let top = model.today.categories.first {
                VStack(spacing: 0) {
                    ForEach(model.today.categories, id: \.category) { total in
                        CategoryBarRow(total: total, maxDuration: top.duration, nameWidth: 108).frame(height: 24)
                    }
                }
            }

            PauseSection()

            Button { WindowManager.shared.showTimeline() } label: {
                Text("Open timeline").font(Theme.ui(14, .semibold))
                    .frame(maxWidth: .infinity).frame(height: 40).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 6) {
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack {
                    Button("Settings") { WindowManager.shared.showSettings() }
                    Spacer()
                    Button("Quit Tempo") { NSApp.terminate(nil) }
                }
                .buttonStyle(.plain)
                .font(Theme.ui(13))
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(18)
        .frame(width: 348)
        .background(Theme.panel)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
    }
}

struct LiveBlockCard: View {
    let block: Block
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(block.category.name).font(Theme.ui(14, .bold))
                LiveBadge()
                Spacer()
                Text(Format.duration(block.duration)).font(Theme.mono(12.5, .semibold))
            }
            Text("\(Format.clock(block.start)) to now, \(block.topNames.joined(separator: ", "))")
                .font(Theme.ui(12.5)).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(block.category.labelColor)
        .background { CategoryFill(category: block.category).clipShape(RoundedRectangle(cornerRadius: 10)) }
    }
}

struct PauseSection: View {
    @EnvironmentObject var model: TempoModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Pause tracking")
            if let until = model.pausedUntil {
                HStack {
                    Text("Paused until \(Format.clock(until))").font(Theme.ui(13.5, .semibold))
                    Spacer()
                    SmallButton("Resume") { model.resume() }
                }
            } else {
                HStack(spacing: 6) {
                    SmallButton("30 min", fill: true) { model.pause(for: 1800) }
                    SmallButton("1 hour", fill: true) { model.pause(for: 3600) }
                    SmallButton("Until tomorrow") { model.pause(for: nil) }.fixedSize()
                }
            }
        }
    }
}
