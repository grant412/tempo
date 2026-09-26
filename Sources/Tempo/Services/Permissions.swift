import AppKit
import ApplicationServices
import Carbon
import UserNotifications

enum PermissionState: Equatable {
    case granted, denied, notAsked, notRunning
}

enum Permissions {
    static func accessibility() -> PermissionState { AXIsProcessTrusted() ? .granted : .denied }

    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Apple Event permission for a browser, without prompting.
    static func automation(bundleID: String) -> PermissionState {
        var target = AEAddressDesc()
        let bytes = Array(bundleID.utf8)
        let created = bytes.withUnsafeBytes {
            AECreateDesc(DescType(typeApplicationBundleID), $0.baseAddress, $0.count, &target)
        }
        guard created == OSErr(noErr) else { return .denied }
        defer { AEDisposeDesc(&target) }
        let status = AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard),
                                                           AEEventID(typeWildCard), false)
        switch status {
        case OSStatus(noErr): return .granted
        case OSStatus(errAEEventWouldRequireUserConsent): return .notAsked
        case OSStatus(procNotFound): return .notRunning
        default: return .denied
        }
    }

    static func notifications() async -> PermissionState {
        guard Bundle.main.bundleIdentifier != nil else { return .denied }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    /// Anchors: "Privacy_Accessibility", "Privacy_Automation".
    static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
