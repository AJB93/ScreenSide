import CoreLocation
import Foundation

/// A named place, e.g. "Home" or "Office". Recognised by the network you're on
/// (router address – no permission needed) and/or by Location Services.
struct Place: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var latitude: Double?
    var longitude: Double?
    var radius: Double = 250 // metres
    /// Router MAC addresses seen at this place (several if e.g. Wi‑Fi and a dock differ).
    var networks: [String]?
    var ssid: String?

    var hasLocation: Bool { latitude != nil && longitude != nil }
    var hasNetwork: Bool { !(networks ?? []).isEmpty }

    func matches(network: NetworkInfo?, location: CLLocation?) -> Bool {
        if let network, networks?.contains(network.routerID) == true { return true }
        guard let latitude, let longitude, let location else { return false }
        // Allow for the fix's own inaccuracy so a fuzzy Wi‑Fi fix still counts.
        return CLLocation(latitude: latitude, longitude: longitude).distance(from: location)
            <= radius + min(location.horizontalAccuracy, 1000)
    }

    var detail: String {
        var parts: [String] = []
        if hasNetwork { parts.append(ssid.map { "Wi‑Fi “\($0)”" } ?? "\(networks!.count) network\(networks!.count == 1 ? "" : "s")") }
        if hasLocation { parts.append("within \(Int(radius)) m") }
        return parts.isEmpty ? "Not set up" : parts.joined(separator: " · ")
    }
}

/// Identifies a monitor from what it reports over EDID.
struct DisplayMatch: Codable, Equatable {
    var vendor: UInt32
    var model: UInt32
    /// nil = any unit of this model (used when the monitor reports no serial).
    var serial: UInt32?
    var name: String

    init(_ d: ConnectedDisplay) {
        vendor = d.vendor
        model = d.model
        serial = d.hasSerial ? d.serial : nil
        name = d.name
    }

    func matches(_ d: ConnectedDisplay) -> Bool {
        vendor == d.vendor && model == d.model && (serial == nil || serial == d.serial)
    }
}

struct Rule: Codable, Identifiable, Equatable {
    var id = UUID()
    /// nil = any external display.
    var display: DisplayMatch?
    /// nil = anywhere.
    var placeID: UUID?
    var side: Side
    var alignment: Alignment = .center
    var enabled = true

    /// Higher is more specific. nil = rule does not apply.
    func score(for d: ConnectedDisplay, currentPlaces: Set<UUID>) -> Int? {
        guard enabled else { return nil }
        var score = 0
        if let display {
            guard display.matches(d) else { return nil }
            score += display.serial != nil ? 4 : 2
        }
        if let placeID {
            guard currentPlaces.contains(placeID) else { return nil }
            score += 1
        }
        return score
    }
}

struct Settings: Codable {
    var rules: [Rule] = []
    var places: [Place] = []
    var autoApply = true
    var onboarded: Bool? = nil
}

enum SettingsStore {
    private static let key = "ScreenSideSettings"

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    static func save(_ s: Settings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }
}
