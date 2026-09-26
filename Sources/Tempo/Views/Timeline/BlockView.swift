import SwiftUI
import TempoCore

struct BlockView: View {
    let block: Block
    let height: CGFloat
    let selected: Bool

    private var range: String {
        "\(Format.clock(block.start)) to \(block.isLive ? "now" : Format.clock(block.end))"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CategoryFill(category: block.category)
            label
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(block.category.labelColor)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 11).stroke(Theme.ink, lineWidth: 2).padding(-4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .help("\(block.category.name), \(range), \(Format.duration(block.duration))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.category.name), \(range), \(Format.duration(block.duration))")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var label: some View {
        if height >= 40 {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(block.category.name).font(Theme.ui(14, .bold))
                    if block.isLive { LiveBadge() }
                    Spacer()
                    Text(Format.duration(block.duration)).font(Theme.mono(12.5, .semibold))
                }
                Text("\(range), \(block.topNames.joined(separator: ", "))").font(Theme.ui(12.5)).lineLimit(1)
            }
            .padding(.horizontal, 12)
            // The two lines are 37 pt tall: blocks under 55 pt center them instead of clipping the second line.
            .padding(.top, min(9, (height - 37) / 2))
        } else if height >= 18 {
            HStack(spacing: 8) {
                Text(block.category.name).font(Theme.ui(13, .bold))
                Text(block.topNames.joined(separator: ", ")).font(Theme.ui(13)).lineLimit(1)
                Spacer()
                Text(Format.duration(block.duration)).font(Theme.mono(12))
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
        }
    }
}
