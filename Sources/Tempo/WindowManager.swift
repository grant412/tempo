import AppKit
import SwiftUI

/// Owns the timeline and settings windows and the focus timer pop-up. AppKit windows hosting
/// SwiftUI, so the menu bar popover and notification clicks can open them without a SwiftUI
/// openWindow environment.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]
    private var focusPanel: FocusPanel?
    /// The session the focus timer pop-up was last shown for.
    private var focusNotesSessionID: Int64?
    /// Bumped on every show, so a slide-out that finishes after a newer show leaves it open.
    private var focusNotesShown = 0
    /// True during the run-out slide-out; a show that lands in it starts over with a slide-in.
    private var slidingAway = false
    private let countdown = FocusNotesCountdown()

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

    /// The focus timer pop-up (focus timer spec 3.4), floating in the top right corner of the
    /// screen under the pointer, over every app and Space. `activate` false leaves the app in
    /// front alone, so a timer that runs out never pulls Grant's typing into the notes box; a
    /// click on the pop-up makes it key. Showing it again for the session it has open only brings
    /// it forward, so a draft being typed survives. `autoClose` (run-out only) starts the 5 s
    /// countdown once it has slid in.
    func showFocusNotes(sessionID: Int64, justEnded: Bool = false, activate: Bool = true, autoClose: Bool = false) {
        countdown.cancel()
        focusNotesShown += 1
        if slidingAway {
            slidingAway = false
            focusPanel?.orderOut(nil)
        }
        if let panel = focusPanel, panel.isVisible, focusNotesSessionID == sessionID {
            present(panel, activate: activate)
            return
        }
        let model = TempoModel.shared
        let session = model.focusSession(id: sessionID)
        let recap = session.map { model.recap(for: $0) }
        let host = NSHostingController(rootView: FocusNotesView(session: session, recap: recap, justEnded: justEnded,
                                                                countdown: countdown)
            .environmentObject(model))
        // Measured before it joins the panel, and never resized by SwiftUI after: inside, the
        // hidden title bar adds 28 pt of inset that would sit empty under the buttons.
        let size = host.view.fittingSize
        host.sizingOptions = []
        let panel = focusPanel ?? makeFocusPanel()
        panel.contentViewController = host
        panel.setContentSize(size)
        // AppKit, not SwiftUI's onHover, so the pointer is seen while another app is in front.
        host.view.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                                 owner: panel, userInfo: nil))
        let mouse = NSEvent.mouseLocation
        if let area = (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: area.maxX - panel.frame.width - 16, y: area.maxY - 16))
        }
        focusPanel = panel
        focusNotesSessionID = sessionID
        let shown = focusNotesShown
        present(panel, activate: activate) { [weak self] in
            guard autoClose, let self, self.focusNotesShown == shown else { return }
            self.startCountdown(panel)
        }
    }

    func closeFocusNotes() {
        countdown.cancel()
        slidingAway = false
        focusPanel?.close()
    }

    /// A pointer already over the pop-up, or a click during the slide-in, counts as a hover.
    private func startCountdown(_ panel: FocusPanel) {
        guard panel.isVisible, !panel.isKeyWindow, !NSMouseInRect(NSEvent.mouseLocation, panel.frame, false) else { return }
        countdown.start { [weak self] in self?.slideAwayFocusNotes() }
    }

    private func stopCountdown() {
        guard countdown.deadline != nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { countdown.cancel() }
    }

    /// The countdown ran out: slides back out to the right, then closes like Skip.
    private func slideAwayFocusNotes() {
        guard let panel = focusPanel, panel.isVisible else { return }
        let shown = focusNotesShown
        slidingAway = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().setFrame(panel.frame.offsetBy(dx: 24, dy: 0), display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                guard self.focusNotesShown == shown, self.slidingAway else { return }
                self.slidingAway = false
                panel.close()
            }
        })
    }

    /// Slides in from the right when it was hidden, then calls `done`.
    private func present(_ panel: NSPanel, activate: Bool, then done: (() -> Void)? = nil) {
        if !panel.isVisible {
            let target = panel.frame
            panel.alphaValue = 0
            panel.setFrame(target.offsetBy(dx: 24, dy: 0), display: false)
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().setFrame(target, display: true)
                panel.animator().alphaValue = 1
            }, completionHandler: {
                MainActor.assumeIsolated { done?() }
            })
        } else {
            panel.orderFrontRegardless()
            done?()
        }
        if activate { panel.makeKey() }
    }

    private func makeFocusPanel() -> FocusPanel {
        let panel = FocusPanel(contentRect: NSRect(x: 0, y: 0, width: FocusNotesView.width, height: 520),
                               styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.title = "Focus timer"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.onPointerEnter = { [weak self] in self?.stopCountdown() }
        return panel
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

/// Takes typing once clicked, without making Tempo the active app. Owns the tracking area that
/// reports the pointer coming over it.
private final class FocusPanel: NSPanel {
    var onPointerEnter: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func mouseEntered(with event: NSEvent) { onPointerEnter?() }
}
