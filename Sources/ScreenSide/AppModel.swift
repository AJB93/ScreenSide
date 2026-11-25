import AppKit
import Combine
import CoreLocation
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var displays: [ConnectedDisplay] = []
    @Published var settings: Settings { didSet { SettingsStore.save(settings) } }
    @Published private(set) var lastAction = "Waiting for displays…"
    @Published private(set) var network: NetworkInfo?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastAction = "Launch at login failed: \(error.localizedDescription)"
            }
        }
    }

    let location = LocationProvider()
    private var lastFingerprints: Set<String> = []
    private var pending: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var onboardingWindow: NSWindow?
    private var bag: Set<AnyCancellable> = []

    var externals: [ConnectedDisplay] { displays.filter { !$0.isBuiltin } }
    var hasBuiltin: Bool { displays.contains(where: \.isBuiltin) }

    init() {
        settings = SettingsStore.load()
        displays = DisplayService.activeDisplays()
        // Re-render the UI when location / permission changes.
        location.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lastFingerprints = [] // treat wake as a fresh plug-in
                self?.scheduleCheck(delay: 3)
            }
        })
        scheduleCheck(delay: 0.5)

        if let i = CommandLine.arguments.firstIndex(of: "--showcase"), i + 1 < CommandLine.arguments.count {
            let which = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showShowcase(which) }
        } else if settings.onboarded != true {
            DispatchQueue.main.async { self.showOnboarding() }
        }
    }

    // MARK: - Detection

    /// Debounced: macOS fires several notifications while a display negotiates its mode.
    func scheduleCheck(delay: Double = 1.5) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            displays = DisplayService.activeDisplays()
            let prints = Set(displays.map(\.fingerprint))
            let newSet = prints != lastFingerprints
            lastFingerprints = prints
            if newSet && settings.autoApply { await applyRules() } else { await refreshNetwork() }
        }
    }

    func refreshNetwork() async {
        network = await NetworkService.current()
    }

    // MARK: - Places

    /// Places you are at right now. Uses the network first (instant, no permission),
    /// and Location Services only if it's allowed and a location-based place needs it.
    private func currentPlaceIDs() async -> Set<UUID> {
        await refreshNetwork()
        var here = Set(settings.places.filter { $0.matches(network: network, location: nil) }.map(\.id))
        let needsLocation = settings.places.contains { $0.hasLocation && !here.contains($0.id) }
        if needsLocation, location.isAuthorized, let loc = await location.refresh() {
            here.formUnion(settings.places.filter { $0.matches(network: nil, location: loc) }.map(\.id))
        }
        return here
    }

    /// The place you're at, using what's already known (no new lookups).
    var currentPlace: Place? {
        settings.places.first { $0.matches(network: network, location: location.location) }
    }

    /// Short label for "here" in the UI.
    var hereName: String {
        currentPlace?.name ?? network?.displayName ?? (location.location != nil ? "this location" : "this place")
    }

    /// The saved place you are at now, creating or enriching one as needed.
    func placeHere() async -> Place? {
        await refreshNetwork()
        let loc = location.isAuthorized ? await location.refresh() : nil
        guard network != nil || loc != nil else { return nil }

        if let i = settings.places.firstIndex(where: { $0.matches(network: network, location: loc) }) {
            // Learn this network / coordinates for next time.
            if let n = network, !(settings.places[i].networks ?? []).contains(n.routerID) {
                settings.places[i].networks = (settings.places[i].networks ?? []) + [n.routerID]
            }
            if settings.places[i].ssid == nil { settings.places[i].ssid = network?.ssid }
            if !settings.places[i].hasLocation, let loc {
                settings.places[i].latitude = loc.coordinate.latitude
                settings.places[i].longitude = loc.coordinate.longitude
            }
            return settings.places[i]
        }
        let p = Place(name: network?.ssid ?? "Place \(settings.places.count + 1)",
                      latitude: loc?.coordinate.latitude, longitude: loc?.coordinate.longitude,
                      networks: network.map { [$0.routerID] }, ssid: network?.ssid)
        settings.places.append(p)
        return p
    }

    // MARK: - Rules

    func bestRule(for d: ConnectedDisplay, places: Set<UUID>) -> Rule? {
        settings.rules
            .compactMap { r in r.score(for: d, currentPlaces: places).map { (r, $0) } }
            .max { $0.1 < $1.1 }?.0
    }

    /// Rule that would apply right now (using already-known network/location).
    func activeRule(for d: ConnectedDisplay) -> Rule? {
        let here = Set(settings.places.filter { $0.matches(network: network, location: location.location) }.map(\.id))
        return bestRule(for: d, places: here)
    }

    func applyRules() async {
        displays = DisplayService.activeDisplays()
        let places = await currentPlaceIDs()
        guard hasBuiltin else { lastAction = "No built-in screen active (lid closed) – nothing to arrange"; return }
        guard !externals.isEmpty else { lastAction = "No external display connected"; return }

        var placements: [(display: ConnectedDisplay, side: Side, alignment: Alignment)] = []
        var summary: [String] = []
        for d in externals {
            if let r = bestRule(for: d, places: places) {
                placements.append((d, r.side, r.alignment))
                summary.append("\(d.name) → \(r.side.label.lowercased())")
            } else {
                summary.append("\(d.name): no rule yet")
            }
        }
        let changed = DisplayService.arrange(placements, among: displays)
        displays = DisplayService.activeDisplays()
        lastAction = (changed ? "Arranged " : "In place: ") + summary.joined(separator: ", ")
    }

    /// Creates or updates the rule for this display (or any display when `display` is nil).
    func setSide(_ side: Side, alignment: Alignment, for display: ConnectedDisplay?, onlyHere: Bool) async {
        var placeID: UUID?
        if onlyHere {
            guard let p = await placeHere() else {
                lastAction = "Couldn't recognise this place – connect to a network or allow Location"
                return
            }
            placeID = p.id
        }
        let match = display.map(DisplayMatch.init)
        if let i = settings.rules.firstIndex(where: { $0.display == match && $0.placeID == placeID }) {
            settings.rules[i].side = side
            settings.rules[i].alignment = alignment
            settings.rules[i].enabled = true
        } else {
            settings.rules.append(Rule(display: match, placeID: placeID, side: side, alignment: alignment))
        }
        await applyRules()
    }

    func describeTarget(_ r: Rule) -> String {
        r.display.map { m in m.serial.map { _ in m.name } ?? "\(m.name) (any unit)" } ?? "Any other display"
    }

    func describePlace(_ r: Rule) -> String {
        guard let pid = r.placeID else { return "Everywhere" }
        return settings.places.first { $0.id == pid }?.name ?? "Deleted place"
    }

    func describe(_ r: Rule) -> String {
        "\(r.side.label), \(r.alignment.label(for: r.side).lowercased()) · \(describePlace(r))"
    }

    func deleteRule(_ r: Rule) { settings.rules.removeAll { $0.id == r.id } }

    func deletePlace(_ p: Place) {
        settings.places.removeAll { $0.id == p.id }
        settings.rules.removeAll { $0.placeID == p.id }
    }

    // MARK: - Onboarding

    func showOnboarding() {
        if let w = onboardingWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView().environmentObject(self))
        w.center()
        onboardingWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// `--showcase welcome|places|ready|menu|settings` opens a panel in its own window,
    /// for screenshots in the README / website.
    private var showcaseWindow: NSWindow?
    func showShowcase(_ which: String) {
        let view: AnyView
        var size = NSSize(width: 560, height: 600)
        switch which {
        case "welcome": view = AnyView(OnboardingView(step: 0))
        case "places": view = AnyView(OnboardingView(step: 1))
        case "ready": view = AnyView(OnboardingView(step: 2))
        case "settings": view = AnyView(SettingsView()); size = NSSize(width: 600, height: 640)
        default:
            view = AnyView(ZStack { AuroraBackground(); MenuContent().glassSurface(cornerRadius: 26).padding(40) })
            size = NSSize(width: 452, height: 700)
        }
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: view.environmentObject(self))
        w.center()
        showcaseWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func finishOnboarding() {
        settings.onboarded = true
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}
