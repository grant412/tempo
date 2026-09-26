import AppKit
import SwiftUI

/// Owns the timeline and settings windows. AppKit windows hosting SwiftUI, so the menu bar
/// popover and notification clicks can open them without a SwiftUI openWindow environment.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func showTimeline() {
        show(id: "timeline", title: "Tempo", size: NSSize(width: 1280, height: 820),
             minSize: NSSize(width: 1100, height: 720), transparentTitlebar: true) {
            AnyView(TimelineWindow().environmentObject(TempoModel.shared))
        }
    }

    func showSettings() {
        show(id: "settings", title: "Settings", size: NSSize(width: 760, height: 900),
             minSize: NSSize(width: 760, height: 560), transparentTitlebar: false) {
            AnyView(SettingsView().environmentObject(TempoModel.shared))
        }
    }

    private func show(id: String, title: String, size: NSSize, minSize: NSSize,
                      transparentTitlebar: Bool, content: () -> AnyView) {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.minSize = minSize
        window.appearance = NSAppearance(named: .aqua)
        if transparentTitlebar {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        } else {
            window.styleMask.remove(.fullSizeContentView)
        }
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        windows[id] = window
    }
}
