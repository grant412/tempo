import AppKit
import SwiftUI
import TempoCore

@main
struct TempoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = TempoModel.shared
    @ObservedObject private var focus = FocusController.shared

    init() {
        if CommandLine.arguments.contains("--write-launch-agent") {
            do {
                try LoginItem.writePlist()
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("could not write launch agent: \(error)\n".utf8))
                exit(1)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView().environmentObject(model).environmentObject(focus)
        } label: {
            MenuBarLabel().environmentObject(model).environmentObject(focus)
        }
        .menuBarExtraStyle(.window)
    }
}
