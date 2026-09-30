import SwiftUI

struct TimelineToolbar: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        HStack(spacing: 14) {
            Text("Tempo").font(Theme.display(20)).kerning(-0.6)
            Spacer()
            HStack(spacing: 8) {
                IconButton(systemName: "chevron.left", label: "Previous day") { model.shiftDay(-1) }
                Text(model.dayTitle).font(Theme.ui(15, .semibold)).frame(minWidth: 230)
                IconButton(systemName: "chevron.right", label: "Next day") { model.shiftDay(1) }
                    .disabled(model.isShowingToday)
                    .opacity(model.isShowingToday ? 0.4 : 1)
                if !model.isShowingToday { SmallButton("Today") { model.goToToday() }.fixedSize() }
            }
            Spacer()
            StatusPill()
            if model.isPaused {
                SmallButton("Resume") { model.resume() }
            } else {
                Menu {
                    Button("Pause 30 minutes") { model.pause(for: 1800) }
                    Button("Pause 1 hour") { model.pause(for: 3600) }
                    Button("Pause until tomorrow") { model.pause(for: nil) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.fill").font(.system(size: 10, weight: .bold))
                        Text("Pause").font(Theme.ui(13, .semibold))
                    }
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
            }
            IconButton(systemName: "slider.horizontal.3", label: "Settings") { WindowManager.shared.showSettings() }
        }
        .padding(.leading, 86)
        .padding(.trailing, 16)
        .frame(height: 52)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct IconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        .accessibilityLabel(label)
        .help(label)
    }
}

struct StatusPill: View {
    @EnvironmentObject var model: TempoModel
    var body: some View {
        let (text, color): (String, Color) = model.isStopped ? ("Stopped", Theme.muted)
            : model.isPaused ? ("Paused", Theme.muted)
            : model.accessibilityGranted ? ("Tracking", Color(hex: "#2fb35e")) : ("Needs permission", Theme.red)
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(Theme.ui(12.5, .medium))
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Theme.chip, in: Capsule())
        .onTapGesture { if !model.accessibilityGranted { WindowManager.shared.showSettings() } }
    }
}
