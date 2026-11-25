import AppKit
import CoreGraphics

/// A display currently active on this Mac, with the identity it reports over EDID
/// (via HDMI / DisplayPort / USB-C).
struct ConnectedDisplay: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let vendor: UInt32
    let model: UInt32
    let serial: UInt32
    let isBuiltin: Bool
    let isMain: Bool
    let isMirrored: Bool
    let bounds: CGRect

    /// True when the monitor gives us a serial number, so we can tell it apart
    /// from another unit of the same model.
    var hasSerial: Bool { serial != 0 }

    var identityDescription: String {
        let v = String(format: "%04X", vendor)
        let m = String(format: "%04X", model)
        return hasSerial ? "Vendor \(v) · Model \(m) · Serial \(serial)" : "Vendor \(v) · Model \(m) · no serial"
    }

    /// Stable key for "this physical set of screens", used to notice plug/unplug.
    var fingerprint: String { "\(vendor)-\(model)-\(serial)-\(isBuiltin)" }
}

enum Side: String, Codable, CaseIterable, Identifiable {
    case left, right, above, below
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .above: "arrow.up"
        case .below: "arrow.down"
        }
    }
}

enum Alignment: String, Codable, CaseIterable, Identifiable {
    case start, center, end
    var id: String { rawValue }
    func label(for side: Side) -> String {
        switch (self, side) {
        case (.center, _): "Centre"
        case (.start, .left), (.start, .right): "Top"
        case (.end, .left), (.end, .right): "Bottom"
        case (.start, _): "Left"
        case (.end, _): "Right"
        }
    }
}

enum DisplayService {
    static func activeDisplays() -> [ConnectedDisplay] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        var names: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                names[n.uint32Value] = screen.localizedName
            }
        }

        return ids.prefix(Int(count)).map { id in
            ConnectedDisplay(
                id: id,
                name: names[id] ?? (CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)"),
                vendor: CGDisplayVendorNumber(id),
                model: CGDisplayModelNumber(id),
                serial: CGDisplaySerialNumber(id),
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                isMain: CGDisplayIsMain(id) != 0,
                isMirrored: CGDisplayIsInMirrorSet(id) != 0,
                bounds: CGDisplayBounds(id)
            )
        }
    }

    /// Places each external display on the requested side of the built-in display.
    /// Returns true if the arrangement was changed.
    @discardableResult
    static func arrange(_ placements: [(display: ConnectedDisplay, side: Side, alignment: Alignment)],
                        among displays: [ConnectedDisplay]) -> Bool {
        guard let builtin = displays.first(where: \.isBuiltin), !builtin.isMirrored else { return false }
        let b = builtin.bounds

        // Lay everything out with the built-in display at (0,0) (CG coords: y grows downward).
        var origins: [CGDirectDisplayID: CGPoint] = [:]
        for d in displays {
            origins[d.id] = CGPoint(x: d.bounds.minX - b.minX, y: d.bounds.minY - b.minY)
        }
        origins[builtin.id] = .zero

        // Running outer edges so several screens on the same side stack outward.
        var leftEdge: CGFloat = 0, rightEdge = b.width, topEdge: CGFloat = 0, bottomEdge = b.height

        for p in placements where !p.display.isBuiltin && !p.display.isMirrored {
            let w = p.display.bounds.width, h = p.display.bounds.height
            func vertical() -> CGFloat {
                switch p.alignment {
                case .start: 0
                case .center: ((b.height - h) / 2).rounded()
                case .end: b.height - h
                }
            }
            func horizontal() -> CGFloat {
                switch p.alignment {
                case .start: 0
                case .center: ((b.width - w) / 2).rounded()
                case .end: b.width - w
                }
            }
            let origin: CGPoint
            switch p.side {
            case .left:  origin = CGPoint(x: leftEdge - w, y: vertical()); leftEdge -= w
            case .right: origin = CGPoint(x: rightEdge, y: vertical()); rightEdge += w
            case .above: origin = CGPoint(x: horizontal(), y: topEdge - h); topEdge -= h
            case .below: origin = CGPoint(x: horizontal(), y: bottomEdge); bottomEdge += h
            }
            origins[p.display.id] = origin
        }

        // The main display (the one with the menu bar) must sit at (0,0).
        let mainOrigin = displays.first(where: \.isMain).flatMap { origins[$0.id] } ?? .zero
        let changed = displays.contains { d in
            guard let o = origins[d.id] else { return false }
            return abs(o.x - mainOrigin.x - d.bounds.minX) > 0.5 || abs(o.y - mainOrigin.y - d.bounds.minY) > 0.5
        }
        guard changed else { return false }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        for d in displays where !d.isMirrored || d.isMain {
            guard let o = origins[d.id] else { continue }
            CGConfigureDisplayOrigin(config, d.id, Int32(o.x - mainOrigin.x), Int32(o.y - mainOrigin.y))
        }
        // .permanently also saves the arrangement in macOS's own display preferences.
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}
