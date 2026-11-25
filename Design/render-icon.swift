// Renders the ScreenSide app icon. Usage: swift Design/render-icon.swift <out-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func glassPanel(_ rect: NSRect, radius: CGFloat, tint: NSColor, in ctx: CGContext) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    // soft drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    tint.withAlphaComponent(0.20).setFill(); path.fill()
    ctx.restoreGState()
    // body: translucent glass
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.34), tint.withAlphaComponent(0.20), NSColor.white.withAlphaComponent(0.08)])!
        .draw(in: path, angle: -70)
    // inner "screen" glow
    let inner = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.07, dy: rect.height * 0.09), xRadius: radius * 0.6, yRadius: radius * 0.6)
    NSGradient(colors: [tint.withAlphaComponent(0.55), tint.blended(withFraction: 0.5, of: .white)!.withAlphaComponent(0.25)])!
        .draw(in: inner, angle: -90)
    // specular top-left highlight
    ctx.saveGState(); path.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)
    ctx.restoreGState()
    // rim light
    path.lineWidth = 5
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.85), NSColor.white.withAlphaComponent(0.12), NSColor.white.withAlphaComponent(0.45)])!
        .draw(in: path.strokedOutline(width: 5), angle: -60)
}

extension NSBezierPath {
    func strokedOutline(width: CGFloat) -> NSBezierPath {
        let cg = self.cgPath.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return NSBezierPath(cgPath: cg)
    }
}

func render(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = g
    let ctx = g.cgContext
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // macOS icon grid: 824pt squircle centred in 1024
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    color(0x0B1024).setFill(); tilePath.fill()
    ctx.restoreGState()

    ctx.saveGState(); tilePath.addClip()
    NSGradient(colors: [color(0x2A1B6E), color(0x101634), color(0x061A2E)])!.draw(in: tilePath, angle: -60)
    // aurora glows
    NSGradient(colors: [color(0x7C5CFF, 0.75), color(0x7C5CFF, 0)])!
        .draw(fromCenter: NSPoint(x: 330, y: 760), radius: 0, toCenter: NSPoint(x: 330, y: 760), radius: 460, options: [])
    NSGradient(colors: [color(0x22D3EE, 0.60), color(0x22D3EE, 0)])!
        .draw(fromCenter: NSPoint(x: 780, y: 300), radius: 0, toCenter: NSPoint(x: 780, y: 300), radius: 440, options: [])

    // laptop (left, lower)
    let laptop = NSRect(x: 150, y: 384, width: 340, height: 232)
    glassPanel(laptop, radius: 30, tint: color(0x8B7BFF), in: ctx)
    let base = NSBezierPath(roundedRect: NSRect(x: 122, y: 350, width: 396, height: 28), xRadius: 14, yRadius: 14)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.85), NSColor.white.withAlphaComponent(0.35)])!.draw(in: base, angle: -90)

    // external monitor (right, larger, floating)
    let monitor = NSRect(x: 534, y: 404, width: 340, height: 250)
    glassPanel(monitor, radius: 32, tint: color(0x2EE6FF), in: ctx)
    NSColor.white.withAlphaComponent(0.5).setFill()
    NSBezierPath(roundedRect: NSRect(x: 678, y: 362, width: 52, height: 44), xRadius: 6, yRadius: 6).fill()
    NSColor.white.withAlphaComponent(0.8).setFill()
    NSBezierPath(roundedRect: NSRect(x: 628, y: 350, width: 152, height: 16), xRadius: 8, yRadius: 8).fill()

    // side arrow pill
    let pill = NSRect(x: 412, y: 704, width: 200, height: 96)
    let pillPath = NSBezierPath(roundedRect: pill, xRadius: 48, yRadius: 48)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: NSColor.black.withAlphaComponent(0.4).cgColor)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.95), color(0xDDE6FF, 0.85)])!.draw(in: pillPath, angle: -90)
    ctx.restoreGState()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 462, y: 752)); arrow.line(to: NSPoint(x: 560, y: 752))
    arrow.move(to: NSPoint(x: 528, y: 782)); arrow.line(to: NSPoint(x: 562, y: 752)); arrow.line(to: NSPoint(x: 528, y: 722))
    arrow.lineWidth = 20; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    NSGradient(colors: [color(0x6D4BFF), color(0x10B5D6)])!.draw(in: arrow.strokedOutline(width: 20), angle: 0)

    // glass sheen over the whole tile
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
    ctx.restoreGState()

    // tile rim
    tilePath.lineWidth = 3
    NSColor.white.withAlphaComponent(0.18).setStroke(); tilePath.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(size: px).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try! render(size: 1024).representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon-1024.png"))
print("ok")
