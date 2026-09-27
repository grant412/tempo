import AppKit
import SwiftUI

/// Owns the timeline and settings windows. AppKit windows hosting SwiftUI, so the menu bar
/// popover and notification clicks can open them without a SwiftUI openWindow environment.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]
    /// The session the focus notes window was last shown for.
    private var focusNotesSessionID: Int64?

    func showTimeline() {
        show(id: "timeline", title: "Tempo", size: NSSize(width: 1280, height: 820),
             minSize: NSSize(width: 1100, height: 720), transparentTitlebar: true) {
            AnyView(TimelineWindow().environmentObject(TempoModel.shared))
        }
        // A reused window never fires onAppear again, so ask the canvas to re-center on now.
        TempoModel.shared.scrollRequest += 1
    }

    func showSettings() {
        show(id: "settings", title: "Settings", size: NSSize(width: 760, height: 900),
             minSize: NSSize(width: 760, height: 560), transparentTitlebar: false) {
            AnyView(SettingsView().environmentObject(TempoModel.shared))
        }
    }

    /// One notes window. Showing it for another session swaps in that session's view. Showing it
    /// again for the session it has open only brings it forward, so a draft being typed survives.
    func showFocusNotes(sessionID: Int64) {
        let size = NSSize(width: 440, height: 560)
        let root = AnyView(FocusNotesView(sessionID: sessionID).environmentObject(TempoModel.shared))
        if let existing = windows["focus-notes"] {
            let isOpen = existing.isVisible || existing.isMiniaturized
            if !(isOpen && focusNotesSessionID == sessionID) {
                existing.contentViewController = NSHostingController(rootView: root)
                existing.setContentSize(size)
            }
        }
        focusNotesSessionID = sessionID
        show(id: "focus-notes", title: "Focus notes", size: size,
             minSize: NSSize(width: 400, height: 460), transparentTitlebar: false) { root }
    }

    func closeFocusNotes() {
        windows["focus-notes"]?.close()
    }

    private func show(id: String, title: String, size: NSSize, minSize: NSSize,
                      transparentTitlebar: Bool, content: () -> AnyView) {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = windows[id] {
            if existing.isMiniaturized { existing.deminiaturize(nil) }
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
