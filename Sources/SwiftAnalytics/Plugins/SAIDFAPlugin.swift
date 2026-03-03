#if canImport(AppTrackingTransparency) && canImport(AdSupport)
import AppTrackingTransparency
import AdSupport
import Foundation

/// Opt-in plugin that requests ATT permission and populates the IDFA field on events.
/// Add this plugin only if your app requires advertising identifier tracking.
///
/// Usage:
/// ```swift
/// analytics.add(plugin: SAIDFAPlugin())
/// ```
public final class SAIDFAPlugin: SAEventPlugin {

    /// Whether ATT permission has been granted.
    public private(set) var isAuthorized = false

    /// The resolved IDFA string, or nil if not authorized.
    public private(set) var idfa: String?

    /// Called after ATT authorization completes.
    public var onAuthorizationComplete: ((ATTrackingManager.AuthorizationStatus) -> Void)?

    public override init(type: SAPluginType = .enrichment) {
        super.init(type: .enrichment)
    }

    public override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        checkAuthorizationStatus()
    }

    public override func execute(event: SAEvent) -> SAEvent? {
        guard let idfa, isAuthorized else { return event }

        var enrichedEvent = event
        enrichedEvent.idfa = idfa
        return enrichedEvent
    }

    // MARK: - ATT Authorization

    /// Request ATT authorization. Call this at an appropriate moment in your app.
    /// Apple requires you to show the permission dialog in a contextually relevant place.
    public func requestAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                self?.handleAuthorizationStatus(status)
            }
        }
    }

    private func checkAuthorizationStatus() {
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            handleAuthorizationStatus(status)
        }
    }

    private func handleAuthorizationStatus(_ status: ATTrackingManager.AuthorizationStatus) {
        switch status {
        case .authorized:
            isAuthorized = true
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            SALogger.info("IDFA authorized: \(idfa ?? "nil")")
        case .denied, .restricted:
            isAuthorized = false
            idfa = nil
            SALogger.info("IDFA denied/restricted")
        case .notDetermined:
            isAuthorized = false
            idfa = nil
            SALogger.debug("IDFA not determined yet")
        @unknown default:
            isAuthorized = false
            idfa = nil
        }

        onAuthorizationComplete?(status)
    }
}
#endif
