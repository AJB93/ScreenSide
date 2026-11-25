import CoreWLAN
import Foundation

/// The network the Mac is on right now, identified by the router's hardware (MAC) address.
/// This needs no permission and works on Wi‑Fi and wired/dock Ethernet alike.
struct NetworkInfo: Equatable {
    /// MAC address of the default gateway, e.g. "28:70:4e:74:63:5f".
    var routerID: String
    /// Wi‑Fi name, when macOS reveals it (it requires Location permission on macOS 14+).
    var ssid: String?
    var interface: String

    var isWiFi: Bool { ssid != nil || CWWiFiClient.shared().interface(withName: interface) != nil }

    var displayName: String {
        if let ssid { return ssid }
        return isWiFi ? "this Wi‑Fi network" : "this wired network"
    }
}

enum NetworkService {
    static func current() async -> NetworkInfo? {
        await Task.detached(priority: .userInitiated) { () -> NetworkInfo? in
            guard let route = run("/sbin/route", ["-n", "get", "default"]) else { return nil }
            func field(_ key: String) -> String? {
                route.split(separator: "\n")
                    .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(key + ":") }
                    .map { $0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }
            }
            guard let gateway = field("gateway"), let iface = field("interface"),
                  let arp = run("/usr/sbin/arp", ["-n", gateway]),
                  let mac = arp.split(separator: " ").first(where: { $0.filter { $0 == ":" }.count == 5 })
            else { return nil }
            let normalised = mac.split(separator: ":")
                .map { $0.count == 1 ? "0" + $0 : String($0) }.joined(separator: ":").lowercased()
            let ssid = CWWiFiClient.shared().interface(withName: iface)?.ssid()
            return NetworkInfo(routerID: normalised, ssid: ssid, interface: iface)
        }.value
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil
    }
}
