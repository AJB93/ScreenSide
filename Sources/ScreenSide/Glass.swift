import AppKit
import SwiftUI

// Liquid Glass on macOS 26 Tahoe, with a material fallback on macOS 14–15.
extension View {
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 16, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(interactive ? Glass.regular.tint(tint).interactive() : Glass.regular.tint(tint),
                             in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background((tint ?? .clear).opacity(0.25), in: RoundedRectangle(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.white.opacity(0.18)))
        }
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }
}

enum Brand {
    static let violet = Color(red: 0.49, green: 0.36, blue: 1.0)
    static let teal = Color(red: 0.13, green: 0.83, blue: 0.93)
    static let gradient = LinearGradient(colors: [violet, teal], startPoint: .leading, endPoint: .trailing)
}

/// The deep aurora backdrop used behind onboarding, matching the app icon.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.11, blue: 0.43),
                                    Color(red: 0.06, green: 0.09, blue: 0.20),
                                    Color(red: 0.02, green: 0.10, blue: 0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Brand.violet.opacity(0.55)).frame(width: 420).blur(radius: 120).offset(x: -180, y: -220)
            Circle().fill(Brand.teal.opacity(0.40)).frame(width: 380).blur(radius: 120).offset(x: 200, y: 240)
        }
        .ignoresSafeArea()
    }
}

/// Monochrome template glyph for the menu bar: a laptop with a screen beside it.
enum MenuBarIcon {
    static let image: NSImage = {
        let img = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            NSColor.black.set()
            // laptop screen + base
            let screen = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 5.25, width: 9, height: 7), xRadius: 1.5, yRadius: 1.5)
            screen.lineWidth = 1.5; screen.stroke()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 2.5, width: 12.5, height: 1.6), xRadius: 0.8, yRadius: 0.8).fill()
            // external monitor (filled, so it reads as "the one being placed")
            NSBezierPath(roundedRect: NSRect(x: 13, y: 6, width: 9, height: 7.5), xRadius: 1.5, yRadius: 1.5).fill()
            NSBezierPath(rect: NSRect(x: 16.75, y: 3.5, width: 1.5, height: 2.5)).fill()
            NSBezierPath(roundedRect: NSRect(x: 15, y: 2.5, width: 5, height: 1.4), xRadius: 0.7, yRadius: 0.7).fill()
            return true
        }
        img.isTemplate = true
        return img
    }()
}
