import AppKit
import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status: CLAuthorizationStatus
    /// Location Services switch for the whole Mac (System Settings › Privacy & Security).
    @Published private(set) var servicesEnabled = true

    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        location = manager.location
        refreshServicesEnabled()
    }

    func refreshServicesEnabled() {
        // Apple advises not to call this on the main thread.
        Task.detached {
            let on = CLLocationManager.locationServicesEnabled()
            await MainActor.run { self.servicesEnabled = on }
        }
    }

    var isAuthorized: Bool { status == .authorizedAlways || status == .authorized }
    var isDenied: Bool { status == .denied || status == .restricted }

    var statusText: String {
        switch status {
        case .notDetermined: "Location not enabled"
        case .denied, .restricted: servicesEnabled ? "Location access is off for ScreenSide" : "Location Services is off on this Mac"
        default:
            if let location { "Location known (±\(Int(location.horizontalAccuracy)) m)" } else { "Locating…" }
        }
    }

    /// Menu bar apps must be frontmost for macOS to show the permission prompt.
    func requestAccess() {
        if isDenied { return openPrivacySettings() }
        NSApp.activate(ignoringOtherApps: true)
        manager.requestAlwaysAuthorization()
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
    }

    /// Fetches a fresh fix, falling back to the last known one after `timeout` seconds.
    func refresh(timeout: TimeInterval = 6) async -> CLLocation? {
        // Never prompt from here: the prompt is only shown when the user asks for it.
        guard isAuthorized else { return location }
        if let location, location.timestamp.timeIntervalSinceNow > -120 { return location }

        manager.requestLocation()
        return await withCheckedContinuation { cont in
            waiters.append(cont)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                self.resume(with: self.location)
            }
        }
    }

    private func resume(with loc: CLLocation?) {
        let w = waiters
        waiters.removeAll()
        w.forEach { $0.resume(returning: loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.location = last
            self.resume(with: last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.resume(with: self.location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            self.status = s
            self.refreshServicesEnabled()
            if self.isAuthorized { manager.requestLocation() }
        }
    }
}
