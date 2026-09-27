import SwiftUI
import TempoCore

/// "What did you get done?" for one focus session (focus timer spec 3.4).
struct FocusNotesView: View {
    @EnvironmentObject var model: TempoModel
    let sessionID: Int64

    @State private var session: FocusSession?
    @State private var recap: SessionRecap?
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        Group {
            if let session {
                content(session)
            } else if loaded {
                missing
            } else {
                Color.clear
            }
        }
        .padding(24)
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
        .onAppear(perform: load)
    }

    private func load() {
        session = model.focusSession(id: sessionID)
        if let session {
            recap = model.recap(for: session)
            text = session.note ?? ""
        }
        loaded = true
    }

    /// "18 min of 25 min" when ended early, unless both round to the same label (End now in the
    /// last 30 s), which reads as the plain planned length.
    private func subtitle(_ s: FocusSession) -> String {
        let range = "\(Format.clock(s.start)) to \(Format.clock(s.end))"
        let actual = Format.minutesLabel(s.duration), planned = Format.minutesLabel(s.planned)
        return s.endedEarly && actual != planned ? "\(range), \(actual) of \(planned)" : "\(range), \(planned)"
    }

    private func content(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What did you get done?").font(Theme.display(26)).kerning(-0.8)
                Text(subtitle(session)).font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Tracked in this session")
                if let recap, let top = recap.categories.first {
                    VStack(spacing: 0) {
                        ForEach(recap.categories, id: \.category) { total in
                            CategoryBarRow(total: total, maxDuration: top.duration, nameWidth: 108).frame(height: 24)
                        }
                    }
                    if !recap.topNames.isEmpty {
                        Text(recap.topNames.joined(separator: ", "))
                            .font(Theme.ui(12.5)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                } else {
                    Text("Nothing tracked in this session.").font(Theme.ui(13)).foregroundStyle(Theme.muted)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Theme.ui(14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                if text.isEmpty {
                    Text("What you got done, what's next...")
                        .font(Theme.ui(14)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))

            HStack(spacing: 8) {
                Spacer()
                SmallButton("Skip") { WindowManager.shared.closeFocusNotes() }.fixedSize()
                Button { save(session) } label: {
                    Text("Save").font(Theme.ui(13, .semibold))
                        .padding(.horizontal, 18).frame(height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 8))
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private var missing: some View {
        VStack(spacing: 14) {
            Text("This session could not be found.").font(Theme.ui(14))
            SmallButton("Close") { WindowManager.shared.closeFocusNotes() }.fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func save(_ session: FocusSession) {
        model.setFocusNote(id: session.id, note: text)
        WindowManager.shared.closeFocusNotes()
    }
}
