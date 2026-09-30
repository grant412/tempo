import Foundation

/// The run-out pop-up's auto close (focus timer spec 3.4): a 5 s bar along its bottom edge, then
/// the pop-up slides away as if Skip were pressed. The pointer coming over it stops this for good.
@MainActor
final class FocusNotesCountdown: ObservableObject {
    static let length: TimeInterval = 5

    /// When the pop-up closes itself; nil when it is not counting down.
    @Published private(set) var deadline: Date?
    private var timer: Timer?

    func start(onDone: @escaping () -> Void) {
        cancel()
        deadline = Date().addingTimeInterval(Self.length)
        let t = Timer(timeInterval: Self.length, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cancel()
                onDone()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        if deadline != nil { deadline = nil }
    }
}
