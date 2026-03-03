#if canImport(CoreLocation) && os(iOS)
import CoreLocation
import Foundation

/// Captures GPS coordinates once per session start (when the host app already has permission).
/// Does NOT request location permission — only reads location when already authorized.
final class SALocationTracker: NSObject, SAPlugin, CLLocationManagerDelegate {

    public let type: SAPluginType = .utility
    public weak var analytics: SwiftAnalytics?

    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocationCoordinate2D?
    private let lock = NSLock()

    func setup(analytics: SwiftAnalytics) {
        self.analytics = analytics

        DispatchQueue.main.async { [weak self] in
            self?.setupLocationManager()
        }
    }

    func execute(event: SAEvent) -> SAEvent? {
        return event
    }

    func teardown() {
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil
        locationManager = nil
        analytics = nil
    }

    // MARK: - Location Manager Setup

    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // coarse accuracy — battery-friendly
        self.locationManager = manager

        // Only start if already authorized (never request permission ourselves)
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation() // Single location request
            SALogger.info("Location tracking started (already authorized)")
        } else {
            SALogger.debug("Location tracking skipped — not authorized (\(status.rawValue))")
        }
    }

    // MARK: - Enrichment

    /// Get the current captured coordinates for event enrichment.
    var latitude: Double? {
        lock.lock()
        defer { lock.unlock() }
        return currentLocation?.latitude
    }

    var longitude: Double? {
        lock.lock()
        defer { lock.unlock() }
        return currentLocation?.longitude
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        lock.lock()
        currentLocation = location.coordinate
        lock.unlock()

        // Stop after first fix — we only need one per session
        manager.stopUpdatingLocation()

        SALogger.debug("Location captured: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        SALogger.warn("Location tracking error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
#endif
