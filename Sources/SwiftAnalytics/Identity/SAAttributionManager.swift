import Foundation

/// Persists UTM attribution parameters across sessions.
/// Captures from deep links and attaches to events automatically.
final class SAAttributionManager {

    private let persistence: SAPersistence
    private let lock = NSLock()

    /// Current UTM parameters (persisted across sessions).
    private(set) var utmSource: String?
    private(set) var utmMedium: String?
    private(set) var utmCampaign: String?
    private(set) var utmTerm: String?
    private(set) var utmContent: String?
    private(set) var referrer: String?

    private static let keyUTMSource = "sa_utm_source"
    private static let keyUTMMedium = "sa_utm_medium"
    private static let keyUTMCampaign = "sa_utm_campaign"
    private static let keyUTMTerm = "sa_utm_term"
    private static let keyUTMContent = "sa_utm_content"
    private static let keyReferrer = "sa_referrer"

    init(persistence: SAPersistence) {
        self.persistence = persistence
        loadFromDisk()
    }

    // MARK: - Update from Deep Link URL

    /// Extract and persist UTM parameters from a URL.
    func updateFromURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        lock.lock()
        defer { lock.unlock() }

        var changed = false

        for item in queryItems {
            guard let value = item.value, !value.isEmpty else { continue }
            switch item.name {
            case "utm_source":
                utmSource = value
                persistence.set(value, forKey: SAAttributionManager.keyUTMSource)
                changed = true
            case "utm_medium":
                utmMedium = value
                persistence.set(value, forKey: SAAttributionManager.keyUTMMedium)
                changed = true
            case "utm_campaign":
                utmCampaign = value
                persistence.set(value, forKey: SAAttributionManager.keyUTMCampaign)
                changed = true
            case "utm_term":
                utmTerm = value
                persistence.set(value, forKey: SAAttributionManager.keyUTMTerm)
                changed = true
            case "utm_content":
                utmContent = value
                persistence.set(value, forKey: SAAttributionManager.keyUTMContent)
                changed = true
            default:
                break
            }
        }

        // Store referrer from the host
        if let host = url.host, !host.isEmpty {
            referrer = host
            persistence.set(host, forKey: SAAttributionManager.keyReferrer)
            changed = true
        }

        if changed {
            SALogger.info("Attribution updated: source=\(utmSource ?? "nil"), campaign=\(utmCampaign ?? "nil")")
        }
    }

    // MARK: - Enrich Event

    /// Attach persisted UTM parameters to an event.
    func enrich(event: inout SAEvent) {
        lock.lock()
        defer { lock.unlock() }

        if let utmSource { event.utmSource = utmSource }
        if let utmMedium { event.utmMedium = utmMedium }
        if let utmCampaign { event.utmCampaign = utmCampaign }
        if let utmTerm { event.utmTerm = utmTerm }
        if let utmContent { event.utmContent = utmContent }
        if let referrer { event.referrer = referrer }
    }

    /// Whether any attribution data is available.
    var hasAttribution: Bool {
        lock.lock()
        defer { lock.unlock() }
        return utmSource != nil || utmCampaign != nil || referrer != nil
    }

    // MARK: - Clear

    func clearAttribution() {
        lock.lock()
        defer { lock.unlock() }

        utmSource = nil
        utmMedium = nil
        utmCampaign = nil
        utmTerm = nil
        utmContent = nil
        referrer = nil

        persistence.set(nil, forKey: SAAttributionManager.keyUTMSource)
        persistence.set(nil, forKey: SAAttributionManager.keyUTMMedium)
        persistence.set(nil, forKey: SAAttributionManager.keyUTMCampaign)
        persistence.set(nil, forKey: SAAttributionManager.keyUTMTerm)
        persistence.set(nil, forKey: SAAttributionManager.keyUTMContent)
        persistence.set(nil, forKey: SAAttributionManager.keyReferrer)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        utmSource = persistence.string(forKey: SAAttributionManager.keyUTMSource)
        utmMedium = persistence.string(forKey: SAAttributionManager.keyUTMMedium)
        utmCampaign = persistence.string(forKey: SAAttributionManager.keyUTMCampaign)
        utmTerm = persistence.string(forKey: SAAttributionManager.keyUTMTerm)
        utmContent = persistence.string(forKey: SAAttributionManager.keyUTMContent)
        referrer = persistence.string(forKey: SAAttributionManager.keyReferrer)
    }
}
