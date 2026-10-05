// Genere Pico/Resources/AppIcon.icns : soleil sur la mer, coche blanche.
// Usage : swift scripts/make-icon.swift
import AppKit

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024
    func c(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    // Plaque (gabarit macOS : 824 px dans 1024, coins 185).
    let plate = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = c(0x000000, 0.28)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    c(0xF7F3EC).setFill()
    platePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    platePath.addClip()
    // Ciel : papier vers peche.
    NSGradient(colors: [c(0xFBE3C4), c(0xF7F3EC)])!.draw(in: plate, angle: 90)
    // Soleil.
    let sun = NSRect(x: 262 * s, y: 380 * s, width: 500 * s, height: 500 * s)
    NSGradient(colors: [c(0xEC6A5C), c(0xF0A020)])!.draw(in: NSBezierPath(ovalIn: sun), angle: 90)
    // Mer : trois bandes ondulees.
    let waves: [(CGFloat, UInt32)] = [(470, 0x5B8DF0), (360, 0x2F6FEB), (250, 0x1F4FB8)]
    for (i, (top, color)) in waves.enumerated() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 100 * s, y: 100 * s))
        path.line(to: NSPoint(x: 100 * s, y: top * s))
        let steps = 60
        for k in 0...steps {
            let t = CGFloat(k) / CGFloat(steps)
            let x = 100 + 824 * t
            let y = top + sin(t * .pi * 3 + CGFloat(i) * 1.3) * 16
            path.line(to: NSPoint(x: x * s, y: y * s))
        }
        path.line(to: NSPoint(x: 924 * s, y: 100 * s))
        path.close()
        c(color).setFill()
        path.fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Coche blanche sur le soleil.
    let check = NSBezierPath()
    check.move(to: NSPoint(x: 400 * s, y: 640 * s))
    check.line(to: NSPoint(x: 480 * s, y: 560 * s))
    check.line(to: NSPoint(x: 640 * s, y: 730 * s))
    check.lineWidth = 58 * s
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    c(0xFFFFFF).setStroke()
    check.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try draw(size: px).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
print(iconset.path)
