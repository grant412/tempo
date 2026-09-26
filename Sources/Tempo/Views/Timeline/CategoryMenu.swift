import SwiftUI
import TempoCore

/// The category picker button used in the inspector and the rules sheet.
struct CategoryMenu: View {
    let current: CategoryID
    let onPick: (CategoryID) -> Void

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
                Text(current == .comms ? "Comms" : current.name).font(Theme.ui(12, .semibold))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
            .foregroundStyle(Theme.ink)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Category: \(current.name)")
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
