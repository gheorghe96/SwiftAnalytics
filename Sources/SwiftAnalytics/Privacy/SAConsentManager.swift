import Foundation

/// Manages GDPR/CCPA/ATT consent state.
/// Events are blocked when the user has opted out.
public final class SAConsentManager {

    private let persistence: SAPersistence
    private let lock = NSLock()

    /// Current consent state.
    public private(set) var state: SAConsentState

    /// Called whenever consent state changes.
    public var onConsentChanged: ((SAConsentState) -> Void)?

    init(persistence: SAPersistence) {
        self.persistence = persistence
        self.state = persistence.consentState
    }

    // MARK: - Consent Control

    /// Opt the user in to tracking.
    public func optIn() {
        lock.lock()
        defer { lock.unlock() }
        state = .optedIn
        persistence.consentState = .optedIn
        persistence.optOut = false
        SALogger.info("User opted in to tracking")
        onConsentChanged?(.optedIn)
    }

    /// Opt the user out of tracking. All event tracking will be paused.
    public func optOut() {
        lock.lock()
        defer { lock.unlock() }
        state = .optedOut
        persistence.consentState = .optedOut
        persistence.optOut = true
        SALogger.info("User opted out of tracking")
        onConsentChanged?(.optedOut)
    }

    /// Reset consent to unknown state.
    public func resetConsent() {
        lock.lock()
        defer { lock.unlock() }
        state = .unknown
        persistence.consentState = .unknown
        persistence.optOut = false
        SALogger.info("Consent state reset to unknown")
        onConsentChanged?(.unknown)
    }

    /// Whether tracking is currently allowed.
    var isTrackingAllowed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state != .optedOut
    }

    /// Whether the user has explicitly opted out.
    var isOptedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state == .optedOut
    }
}

// MARK: - Consent Before Plugin

/// Plugin that blocks events when user has opted out.
final class SAConsentPlugin: SAEventPlugin {

    private weak var consentManager: SAConsentManager?

    init(consentManager: SAConsentManager) {
        self.consentManager = consentManager
        super.init(type: .before)
    }

    override func execute(event: SAEvent) -> SAEvent? {
        guard consentManager?.isTrackingAllowed == true else {
            SALogger.verbose("Event blocked by consent: \(event.eventType)")
            return nil
        }
        return event
    }
}
