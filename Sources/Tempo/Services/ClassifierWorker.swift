import Foundation
import TempoCore

/// Once a minute, sends up to 20 unknown apps and sites to Claude (spec section 7.4).
@MainActor
final class ClassifierWorker {
    static let shared = ClassifierWorker()
    private var timer: Timer?
    private var inFlight = false

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
        t.tolerance = 10
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func flush() {
        let model = TempoModel.shared
        guard !inFlight, !model.keyRejected, let queue = model.queue, queue.pendingCount > 0,
              let key = Keychain.read(), !key.isEmpty else { return }
        let batch = queue.nextBatch()
        let classifier = ClaudeClassifier(apiKey: key)
        inFlight = true
        Task { @MainActor in
            defer { self.inFlight = false }
            do {
                let results = try await classifier.classify(batch)
                let inserted = try queue.complete(batch: batch, results: results, now: Date())
                Log.info("classified \(results.count) of \(batch.count), \(inserted) new rules")
                if inserted > 0 {
                    model.reloadRules()
                    model.refresh()
                }
            } catch ClassifierError.unauthorized {
                queue.requeue(batch)
                model.setKeyRejected(true)
                Log.error("classify: API key rejected")
            } catch {
                Log.error("classify: \(error)")
                try? queue.fail(batch: batch, now: Date())
            }
        }
    }
}
