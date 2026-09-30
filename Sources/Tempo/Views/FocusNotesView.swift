import SwiftUI
import TempoCore

/// The focus timer pop-up (focus timer spec 3.4): a summary of the session, then "What did you
/// get done?" with the notes box open. WindowManager shows it in the top right corner.
struct FocusNotesView: View {
    static let width: CGFloat = 400

    @EnvironmentObject var model: TempoModel
    let session: FocusSession?
    let recap: SessionRecap?
    /// True when the timer just ran out or was ended; false when reopened from the timeline.
    let justEnded: Bool
    @State private var text: String

    init(session: FocusSession?, recap: SessionRecap?, justEnded: Bool) {
        self.session = session
        self.recap = recap
        self.justEnded = justEnded
        _text = State(initialValue: session?.note ?? "")
    }

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                missing
            }
        }
        .padding(EdgeInsets(top: 16, leading: 22, bottom: 20, trailing: 22))
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel)
        .foregroundStyle(Theme.ink)
        .ignoresSafeArea()
        .themed()
    }

    /// "18 min of 25 min" when ended early, unless both round to the same label (End now in the
    /// last 30 s), which reads as the plain planned length.
    private func subtitle(_ s: FocusSession) -> String {
        let range = "\(Format.clock(s.start)) to \(Format.clock(s.end))"
        let actual = Format.minutesLabel(s.duration), planned = Format.minutesLabel(s.planned)
        return s.endedEarly && actual != planned ? "\(range), \(actual) of \(planned)" : "\(range), \(planned)"
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
            Eyebrow(text: "Focus timer")
            Spacer()
            Button { WindowManager.shared.closeFocusNotes() } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.muted)
            .help("Close")
            .accessibilityLabel("Close")
        }
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(height: 1) }

    private func content(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            VStack(alignment: .leading, spacing: 4) {
                Text(justEnded ? "Your focus timer is done." : "Your focus session")
                    .font(Theme.display(24)).kerning(-0.6)
                Text(subtitle(session)).font(Theme.ui(13)).foregroundStyle(Theme.muted)
            }
            divider
            summary(session)
            divider
            VStack(alignment: .leading, spacing: 8) {
                Text("What did you get done?").font(Theme.ui(15, .semibold))
                TextEditor(text: $text)
                    .font(Theme.ui(14))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .padding(8)
                    .frame(height: 96)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
                    .accessibilityLabel("What did you get done?")
            }
            HStack(spacing: 8) {
                Spacer()
                SmallButton("Skip") { WindowManager.shared.closeFocusNotes() }.fixedSize()
                Button { save(session) } label: {
                    Text("Save").font(Theme.ui(13, .semibold))
                        .padding(.horizontal, 18).frame(height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.panel)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 8))
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    /// Time at the keyboard, its share of the session, Distraction, and the top three categories.
    @ViewBuilder private func summary(_ session: FocusSession) -> some View {
        if let recap, let top = recap.categories.first {
            let share = min(100, Int((recap.total / max(session.duration, 1) * 100).rounded()))
            let distraction = recap.categories.first { $0.category == .distraction }?.duration ?? 0
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 28) {
                    MiniStat(value: Format.duration(recap.total), label: "at the keyboard")
                    MiniStat(value: "\(share)%", label: "of the session")
                    MiniStat(value: Format.duration(distraction), label: "distraction")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Top categories")
                    VStack(spacing: 0) {
                        ForEach(recap.categories.prefix(3), id: \.category) { total in
                            CategoryBarRow(total: total, maxDuration: top.duration, nameWidth: 108).frame(height: 24)
                        }
                    }
                    if !recap.topNames.isEmpty {
                        Text(recap.topNames.joined(separator: ", "))
                            .font(Theme.ui(12.5)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
            }
        } else {
            Text("Nothing tracked in this session.").font(Theme.ui(13)).foregroundStyle(Theme.muted)
        }
    }

    private var missing: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text("This session could not be found.").font(Theme.ui(14))
            HStack {
                Spacer()
                SmallButton("Close") { WindowManager.shared.closeFocusNotes() }.fixedSize()
            }
        }
    }

    private func save(_ session: FocusSession) {
        model.setFocusNote(id: session.id, note: text)
        WindowManager.shared.closeFocusNotes()
    }
}
