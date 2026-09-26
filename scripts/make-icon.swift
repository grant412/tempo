// Usage: swift scripts/make-icon.swift build  -> writes build/AppIcon.icns
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build"
let iconset = "\(outDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.09
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    color(0x1d1b18).setFill()
    NSBezierPath(roundedRect: tile, xRadius: s * 0.19, yRadius: s * 0.19).fill()
    let barH = tile.height * 0.19
    let gap = tile.height * 0.08
    let left = tile.minX + tile.width * 0.16
    let full = tile.width * 0.68
    let bars: [(CGFloat, UInt32)] = [(1.0, 0x2870cc), (0.65, 0x1baf7a), (0.85, 0x9085e9)]
    var y = tile.maxY - tile.height * 0.2 - barH
    for (w, hex) in bars {
        color(hex).setFill()
        NSBezierPath(roundedRect: NSRect(x: left, y: y, width: full * w, height: barH),
                     xRadius: barH * 0.38, yRadius: barH * 0.38).fill()
        y -= barH + gap
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
    ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024),
]
for (name, px) in sizes {
    try png(px).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(name).png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", "\(outDir)/AppIcon.icns"]
try p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote \(outDir)/AppIcon.icns" : "iconutil failed")
