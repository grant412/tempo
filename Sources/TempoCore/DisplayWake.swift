/// One "keep the display awake" power assertion, as macOS reports it per owning process.
public struct DisplayWakeAssertion: Equatable, Sendable {
    public var ownerProcess: String
    public var name: String
    public init(ownerProcess: String, name: String) {
        self.ownerProcess = ownerProcess
        self.name = name
    }
}

public enum DisplayWake {
    /// Owners whose display-wake assertions say nothing about a call or video the person is watching.
    /// coreaudiod opens one per audio session and leaks them for days (seen at 121 hours on
    /// 2026-11-21), which kept idle detection switched off.
    public static let ignoredOwners: Set<String> = ["coreaudiod"]

    /// True when some assertion means a call or video is genuinely holding the screen on.
    public static func holdsPresence(_ assertions: [DisplayWakeAssertion]) -> Bool {
        assertions.contains { !ignoredOwners.contains($0.ownerProcess) }
    }
}
