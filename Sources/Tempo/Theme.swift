import SwiftUI
import TempoCore

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255, opacity: 1)
    }
}

enum Theme {
    static let bg = Color(hex: "#f6f3ec")
    static let panel = Color.white
    static let line = Color(hex: "#e7e1d5")
    static let grid = Color(hex: "#ece6da")
    static let grid2 = Color(hex: "#f3efe7")
    static let ink = Color(hex: "#1d1b18")
    static let muted = Color(hex: "#6b655b")
    static let chip = Color(hex: "#f1ece2")
    static let track = Color(hex: "#efeae0")
    static let granted = Color(hex: "#15924b")
    static let grantedBg = Color(hex: "#e4f5ea")
    static let stripeA = Color(hex: "#b8b3a8")
    static let stripeB = Color(hex: "#c9c4ba")

    static func display(_ size: CGFloat) -> Font { .custom("Bricolage Grotesque", size: size).weight(.heavy) }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Geist", size: size).weight(weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Geist Mono", size: size).weight(weight).monospacedDigit()
    }
    static func eyebrow() -> Font { mono(11, .medium) }
}

extension CategoryID {
    var fill: Color { Color(hex: fillHex) }
    var labelColor: Color { lightText ? .white : Theme.ink }
}

/// Uncategorized: 135 degree stripes of #b8b3a8 and #c9c4ba.
struct StripeFill: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.stripeA))
            var x = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + 5, y: size.height))
                p.addLine(to: CGPoint(x: x + 5 + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.stripeB))
                x += 10
            }
        }
    }
}

struct CategoryFill: View {
    let category: CategoryID
    var body: some View {
        if category == .uncategorized { StripeFill() } else { category.fill }
    }
}

struct CategorySwatch: View {
    let category: CategoryID
    var size: CGFloat = 10
    var body: some View {
        CategoryFill(category: category)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(Theme.eyebrow()).tracking(1.1).foregroundStyle(Theme.muted)
    }
}

struct CategoryBarRow: View {
    let total: CategoryTotal
    let maxDuration: TimeInterval
    var nameWidth: CGFloat = 104

    var body: some View {
        HStack(spacing: 10) {
            CategorySwatch(category: total.category)
            Text(total.category.name).font(Theme.ui(13.5)).frame(width: nameWidth, alignment: .leading)
            GeometryReader { g in
                CategoryFill(category: total.category)
                    .frame(width: max(2, g.size.width * total.duration / max(maxDuration, 1)), height: 5)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 5)
            Text(Format.duration(total.duration)).font(Theme.mono(12)).lineLimit(1)
                .frame(width: 58, alignment: .trailing)
        }
        .frame(height: 26)
        .foregroundStyle(Theme.ink)
    }
}

struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle().frame(width: 6, height: 6)
            Text("LIVE").font(Theme.mono(10.5, .semibold)).tracking(0.6)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 1)
        .background(Color.white.opacity(0.22), in: Capsule())
    }
}

struct SmallButton: View {
    let title: String
    var fill = false
    let action: () -> Void

    init(_ title: String, fill: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.fill = fill
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(13, .semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(maxWidth: fill ? .infinity : nil)
                .frame(height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
    }
}

struct StatusChip: View {
    let text: String
    var foreground = Theme.granted
    var background = Theme.grantedBg
    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(10.5, .semibold)).tracking(0.4)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 4))
    }
}

struct Card: ViewModifier {
    var padding: EdgeInsets
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
            .shadow(color: Theme.ink.opacity(0.06), radius: 15, y: 10)
    }
}

extension View {
    func card(_ padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)) -> some View {
        modifier(Card(padding: padding))
    }
}
