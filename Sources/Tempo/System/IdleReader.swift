import CoreGraphics
import Darwin
import Foundation
import TempoCore
import IOKit.pwr_mgt

enum IdleReader {
    /// Seconds since the last keyboard, mouse, or trackpad input.
    static func secondsSinceInput() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// True while a call or playing video holds the display awake. Assertions the audio daemon
    /// leaks are ignored (see DisplayWake), so they cannot switch idle detection off.
    static func displaySleepPrevented() -> Bool {
        DisplayWake.holdsPresence(displayWakeAssertions())
    }

    static func displayWakeAssertions() -> [DisplayWakeAssertion] {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let dict = byProcess?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }
        var out: [DisplayWakeAssertion] = []
        for (pid, list) in dict {
            for a in list {
                let type = a[kIOPMAssertionTypeKey as String] as? String
                guard type == kIOPMAssertionTypePreventUserIdleDisplaySleep as String
                    || type == kIOPMAssertionTypeNoDisplaySleep as String else { continue }
                let level = a["AssertLevel"] as? Int ?? 255
                guard level > 0 else { continue }
                let owner = a["Process Name"] as? String ?? processName(pid.int32Value)
                out.append(DisplayWakeAssertion(ownerProcess: owner,
                                                name: a[kIOPMAssertionNameKey as String] as? String ?? ""))
            }
        }
        return out
    }

    private static func processName(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buf, UInt32(buf.count)) > 0 else { return "" }
        return String(cString: buf)
    }
}
