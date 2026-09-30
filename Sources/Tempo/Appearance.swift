import AppKit
import SwiftUI

/// Light or dark, from the sun and moon switch in the menu. Saved in UserDefaults, so it
/// survives a relaunch. Light is the default.
enum Appearance {
    static var isDark: Bool { UserDefaults.standard.bool(forKey: AppSettings.Keys.darkMode) }

    static func nsAppearance(dark: Bool) -> NSAppearance? {
        NSAppearance(named: dark ? .darkAqua : .aqua)
    }

    /// Alerts and menus follow the app's appearance; each window's views follow `.themed()`.
    @MainActor static func apply() {
        NSApp.appearance = nsAppearance(dark: isDark)
    }

    @MainActor static func setDark(_ dark: Bool) {
        UserDefaults.standard.set(dark, forKey: AppSettings.Keys.darkMode)
        apply()
    }
}

extension View {
    /// Every window's root view: sets the color scheme the Theme tokens resolve from, and gives
    /// the hosting window (menu dropdown, popover, sheet, or app window) the matching chrome.
    func themed() -> some View { modifier(Themed()) }
}

private struct Themed: ViewModifier {
    @AppStorage(AppSettings.Keys.darkMode) private var dark = false

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, dark ? .dark : .light)
            .background(WindowAppearance(dark: dark))
    }
}

/// Sets its window's appearance, so title bars, popover arrows, and scroll bars match the views.
private struct WindowAppearance: NSViewRepresentable {
    let dark: Bool

    func makeNSView(context: Context) -> SyncView { SyncView() }

    func updateNSView(_ view: SyncView, context: Context) { view.dark = dark }

    final class SyncView: NSView {
        var dark = false { didSet { apply() } }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            window?.appearance = Appearance.nsAppearance(dark: dark)
        }
    }
}
