import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var model: TempoModel
    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuGlyph.image)
            Text(model.menuBarText)
        }
    }
}
