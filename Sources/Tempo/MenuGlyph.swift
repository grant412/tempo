import AppKit

/// Three stacked calendar blocks, drawn as a template image so the menu bar tints it.
enum MenuGlyph {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 1.5, width: 14, height: 3.6), xRadius: 1.4, yRadius: 1.4).fill()
            NSColor.black.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 6.2, width: 9, height: 3.6), xRadius: 1.4, yRadius: 1.4).fill()
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 10.9, width: 12, height: 3.6), xRadius: 1.4, yRadius: 1.4).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
