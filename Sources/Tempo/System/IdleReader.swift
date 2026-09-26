import CoreGraphics
import IOKit.pwr_mgt

enum IdleReader {
    /// Seconds since the last keyboard, mouse, or trackpad input.
    static func secondsSinceInput() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// True while some app holds a display-sleep assertion: calls and playing video.
    static func displaySleepPrevented() -> Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Any] else { return false }
        return ((dict["PreventUserIdleDisplaySleep"] as? Int) ?? 0) > 0
    }
}
