import AppKit
import SwiftUI
import TempoCore

struct MenuBarView: View {
    @EnvironmentObject var model: TempoModel
    @ObservedObject private var blocker = BlockEnforcer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Today so far")
                        Text(Format.duration(model.today.total)).font(Theme.display(46)).kerning(-1.6)
                    }
                    Spacer(minLength: 12)
                    AppearanceToggle()
                }
                if let line = model.keyboardLine {
                    Text(line).font(Theme.ui(13)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
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

            FocusTimerSection()

            if let w = blocker.distractionWindow {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .semibold))
                    Text("Blocking Distraction until \(Format.lockEnd(w.end, now: Date(), calendar: .autoupdatingCurrent))")
                        .font(Theme.ui(13.5, .semibold))
                }
            }

            PauseSection()

            Button { WindowManager.shared.showTimeline() } label: {
                Text("Open dashboard").font(Theme.ui(14, .semibold))
                    .frame(maxWidth: .infinity).frame(height: 40).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.panel)
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
        .themed()
    }
}

/// Light and dark in one pill: a sun and a moon, with the knob under the one in use.
struct AppearanceToggle: View {
    @AppStorage(AppSettings.Keys.darkMode) private var dark = false

    var body: some View {
        Button { Appearance.setDark(!dark) } label: {
            ZStack(alignment: dark ? .trailing : .leading) {
                Capsule().fill(Theme.chip)
                Circle().fill(Theme.panel)
                    .overlay(Circle().stroke(Theme.line))
                    .frame(width: 22, height: 22)
                    .padding(3)
                HStack(spacing: 0) {
                    symbol("sun.max.fill", active: !dark)
                    symbol("moon.fill", active: dark)
                }
            }
            .frame(width: 56, height: 28)
            .animation(.snappy(duration: 0.2), value: dark)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(dark ? "Switch to light mode" : "Switch to dark mode")
        .accessibilityLabel("Dark mode")
        .accessibilityValue(dark ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    private func symbol(_ name: String, active: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(active ? Theme.ink : Theme.muted)
            .frame(width: 28, height: 28)
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
            if model.isStopped {
                HStack {
                    Text("Tracking stopped").font(Theme.ui(13.5, .semibold))
                    Spacer()
                    SmallButton("Resume") { model.resume() }
                }
            } else if let until = model.pausedUntil {
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
                SmallButton("Stop tracking", fill: true) { model.stop() }
            }
        }
    }
}
