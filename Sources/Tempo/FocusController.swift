import AppKit
import TempoCore

/// The running focus timer (focus timer spec 4.2). Memory only: a quit or crash drops it.
/// Kept apart from TempoModel so the 1 s tick redraws only the timer views, not the timeline.
@MainActor
final class FocusController: ObservableObject {
    static let shared = FocusController()

    @Published private(set) var timer: FocusTimer?
    @Published private(set) var now = Date()
    private var ticker: Timer?

    var remaining: TimeInterval { timer?.remaining(at: now) ?? 0 }

    func start(seconds: TimeInterval) {
        guard timer == nil else { return }
        let n = Date()
        now = n
        timer = FocusTimer(start: n, planned: seconds)
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    /// Saves the session ending now and opens its pop-up, ready to type in. No chime: Grant is
    /// already here.
    func endNow() {
        guard let timer else { return }
        let end = min(Date(), timer.end)
        clear()
        if let session = TempoModel.shared.saveFocusSession(timer, end: end) {
            WindowManager.shared.showFocusNotes(sessionID: session.id, justEnded: true, activate: true)
        }
    }

    func discard() { clear() }

    /// Runs out with the chime and the pop-up, which leaves the app in front alone and closes
    /// itself after 5 s unless the pointer comes over it. Tempo plays the chime itself, so
    /// notification settings and Focus modes cannot mute it. A Mac asleep at the end catches up
    /// on wake; the session still ends at the planned end.
    private func tick() {
        now = Date()
        guard let timer, timer.isDone(at: now) else { return }
        clear()
        if let session = TempoModel.shared.saveFocusSession(timer, end: timer.end) {
            Self.chime?.play()
            WindowManager.shared.showFocusNotes(sessionID: session.id, justEnded: true, activate: false,
                                                autoClose: true)
        }
    }

    /// macOS's "Glass": one short ching.
    private static let chime = NSSound(named: "Glass")

    private func clear() {
        ticker?.invalidate()
        ticker = nil
        timer = nil
    }
}
