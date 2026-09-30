import SwiftUI
import TempoCore

/// The dropdown's focus timer: start one from the preset popover, or watch it count down
/// (focus timer spec 3.1).
struct FocusTimerSection: View {
    @EnvironmentObject var focus: FocusController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Focus timer")
            if let timer = focus.timer {
                RunningTimerRow(timer: timer, remaining: focus.remaining)
            } else {
                StartTimerRow()
            }
        }
    }
}

/// Hovering (or clicking) opens the preset popover beside the row.
struct StartTimerRow: View {
    @EnvironmentObject var focus: FocusController
    @State private var showPresets = false
    @State private var hovering = false

    var body: some View {
        Button { showPresets = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 13, weight: .semibold))
                Text("Start a timer").font(Theme.ui(14, .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .background(hovering || showPresets ? Theme.chip : Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        .onHover { inside in
            hovering = inside
            guard inside else { return }
            // A short delay, like a native submenu, so passing over the row does not open it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if hovering { showPresets = true }
            }
        }
        .popover(isPresented: $showPresets, arrowEdge: .leading) {
            TimerPresetPopover { seconds in
                showPresets = false
                focus.start(seconds: seconds)
            }
        }
    }
}

struct TimerPresetPopover: View {
    let onStart: (TimeInterval) -> Void
    @State private var custom = ""

    private var customMinutes: Int? { FocusTimer.customMinutes(custom) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(text: "Start a timer").padding(.horizontal, 10).padding(.bottom, 4)
            ForEach(FocusTimer.presets, id: \.self) { seconds in
                PresetRow(title: Format.minutesLabel(seconds)) { onStart(seconds) }
            }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 6)
            HStack(spacing: 6) {
                Text("Custom").font(Theme.ui(13.5))
                TextField("", text: $custom, prompt: Text("45"))
                    .textFieldStyle(.plain)
                    .font(Theme.mono(13))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40, height: 26)
                    .padding(.horizontal, 6)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
                    .onSubmit(startCustom)
                Text("min").font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
                Spacer()
                SmallButton("Start") { startCustom() }
                    .fixedSize()
                    .disabled(customMinutes == nil)
                    .opacity(customMinutes == nil ? 0.45 : 1)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: 236)
        .background(Theme.panel)
        .foregroundStyle(Theme.ink)
        .themed()
    }

    private func startCustom() {
        guard let minutes = customMinutes else { return }
        onStart(TimeInterval(minutes * 60))
    }
}

struct PresetRow: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title).font(Theme.ui(13.5, .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering ? Theme.chip : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}

struct RunningTimerRow: View {
    @EnvironmentObject var focus: FocusController
    let timer: FocusTimer
    let remaining: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 14, weight: .semibold))
                Text(Format.countdown(remaining)).font(Theme.mono(18, .semibold)).monospacedDigit()
                    + Text(" left").font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
                Spacer()
                SmallButton("End now") { focus.endNow() }.fixedSize()
                SmallButton("Discard") { focus.discard() }.fixedSize()
            }
            Text("\(Format.minutesLabel(timer.planned)), started \(Format.clock(timer.start))")
                .font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
        }
    }
}
