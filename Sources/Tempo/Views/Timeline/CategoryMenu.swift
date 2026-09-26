import SwiftUI
import TempoCore

/// The category picker button used in the inspector and the rules sheet.
struct CategoryMenu: View {
    let current: CategoryID
    let onPick: (CategoryID) -> Void

    /// One width for every label, so item names keep their room and durations line up.
    /// Fits the widest label, "Distraction" in Geist semibold 12 (CoreText 63.6 pt, SwiftUI 64):
    /// 8 padding + 8 swatch + 5 + 64 text + 5 + 11 chevron + 8 padding = 109, plus 3 pt of slack.
    static let labelWidth: CGFloat = 112

    var body: some View {
        Menu {
            ForEach(CategoryID.assignable, id: \.self) { c in
                Button {
                    onPick(c)
                } label: {
                    if c == current { Label(c.name, systemImage: "checkmark") } else { Text(c.name) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                CategorySwatch(category: current, size: 8)
                Text(label).font(Theme.ui(12, .semibold)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 8)
            .frame(width: Self.labelWidth, height: 28)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
            .foregroundStyle(Theme.ink)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Category: \(current.name)")
    }

    private var label: String {
        switch current {
        case .uncategorized: "Pick one"
        case .comms: "Comms"
        default: current.name
        }
    }
}

/// A rounded chip that assigns one category.
struct CategoryChip: View {
    let category: CategoryID
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                CategorySwatch(category: category, size: 8)
                Text(category.name).font(Theme.ui(12.5, .semibold))
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .background(Theme.panel, in: Capsule())
        .overlay(Capsule().stroke(Theme.line))
    }
}
