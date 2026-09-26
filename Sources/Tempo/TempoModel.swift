import Foundation

@MainActor
final class TempoModel: ObservableObject {
    static let shared = TempoModel()
    var menuBarText: String { "Tempo" }
    func start() { Log.info("started") }
}
