import SwiftUI
import TempoCore

struct MenuBarLabel: View {
    @EnvironmentObject var model: TempoModel
    @EnvironmentObject var focus: FocusController
    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuGlyph.image)
            label
        }
    }

    /// One Text with the clock symbol inside it: a MenuBarExtra label is not guaranteed to lay
    /// out more than one image and one text (focus timer spec 3.2).
    private var label: Text {
        guard focus.timer != nil else { return Text(model.menuBarText).monospacedDigit() }
        return Text("\(model.menuBarText)  \(Image(systemName: "timer")) \(Format.countdown(focus.remaining))")
            .monospacedDigit()
    }
}
