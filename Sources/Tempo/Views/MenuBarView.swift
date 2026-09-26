import AppKit
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tempo")
            Button("Open timeline") { WindowManager.shared.showTimeline() }
            Button("Quit Tempo") { NSApp.terminate(nil) }
        }
        .padding(16)
    }
}
