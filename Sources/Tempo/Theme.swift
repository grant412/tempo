import AppKit
import SwiftUI
import TempoCore

private func rgb(_ hex: String) -> (Double, Double, Double) {
    var value: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
    return (Double((value >> 16) & 0xff) / 255, Double((value >> 8) & 0xff) / 255, Double(value & 0xff) / 255)
}

extension Color {
    init(hex: String) {
        let (r, g, b) = rgb(hex)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

extension NSColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        let (r, g, b) = rgb(hex)
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

/// Light values are the locked Calendar artboard; dark values are its CalendarDark artboard.
/// Each token resolves from the view's color scheme, which `.themed()` sets from the menu's
/// sun and moon switch.
enum Theme {
    static let bg = pair("#f6f3ec", "#121110")
    static let panel = pair("#ffffff", "#1a1917")
    static let line = pair("#e7e1d5", "#2a2825")
    static let grid = pair("#ece6da", "#262420")
    static let grid2 = pair("#f3efe7", "#201f1c")
    static let ink = pair("#1d1b18", "#f3efe6")
    static let muted = pair("#6b655b", "#a39d92")
    static let chip = pair("#f1ece2", "#26241f")
    static let track = pair("#efeae0", "#26241f")
    /// The stripes in an Away gap on the timeline.
    static let hatch = pair("#f1ece2", "#22201d")
    static let granted = pair("#15924b", "#5cc98a")
    static let grantedBg = pair("#e4f5ea", "#173524")
    static let red = pair("#c0382f", "#f08a80")
    static let redSoft = pair("#fae8e6", "#3a1f1c")
    /// A switch that is on. Ink in light; in dark, ink would put the white knob on cream.
    static let switchOn = pair("#1d1b18", "#7d776c")
    static let shadow = pair(NSColor(hex: "#1d1b18", alpha: 0.06), NSColor(hex: "#000000", alpha: 0.35))
    /// Ink on category fills. The fills stay the same in dark mode, so their labels do too.
    static let blockInk = Color(hex: "#1d1b18")
    static let stripeA = Color(hex: "#b8b3a8")
    static let stripeB = Color(hex: "#c9c4ba")

    private static func pair(_ light: String, _ dark: String) -> Color {
        pair(NSColor(hex: light), NSColor(hex: dark))
    }

    private static func pair(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light })
    }

    static func display(_ size: CGFloat) -> Font { .custom("Bricolage Grotesque", size: size).weight(.heavy) }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Geist", size: size).weight(weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Geist Mono", size: size).weight(weight).monospacedDigit()
    }
    static func eyebrow() -> Font { mono(11, .medium) }
}

extension CategoryID {
    var fill: Color { Color(hex: fillHex) }
    var labelColor: Color { lightText ? .white : Theme.blockInk }
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

/// A card's rounded panel surface. The shadow sits on this shape alone, so nothing inside a card casts one.
struct CardSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18).fill(Theme.panel).shadow(color: Theme.shadow, radius: 15, y: 10)
    }
}

struct Card: ViewModifier {
    var padding: EdgeInsets
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(CardSurface())
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
    }
}

extension View {
    func card(_ padding: EdgeInsets = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)) -> some View {
        modifier(Card(padding: padding))
    }
}

/// Stands in for a category menu while the Distraction block locks it (site blocking spec 3.4).
struct LockedBadge: View {
    let until: Date?

    private var text: String {
        until.map { "Locked until \(Format.lockEnd($0, now: Date(), calendar: .autoupdatingCurrent))" } ?? "Locked"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
            Text("Locked").font(Theme.ui(12, .semibold))
        }
        .padding(.horizontal, 8)
        .frame(width: CategoryMenu.labelWidth, height: 28, alignment: .leading)
        .foregroundStyle(Theme.ink)
        .background(Theme.chip, in: RoundedRectangle(cornerRadius: 8))
        .help(text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// A weekday toggle in the Distraction block schedule: ink when on, chip color when off.
struct DayChip: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).font(Theme.ui(12.5, .semibold))
                .frame(width: 42, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(on ? Theme.panel : Theme.ink)
        .background(on ? Theme.ink : Theme.chip, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
