import Foundation

/// UserDefaults-based persistence for identity and session state.
final class SAPersistence {

    private let defaults: UserDefaults
    private let suiteName: String?

    init(apiKey: String) {
        self.suiteName = "com.swiftanalytics.\(apiKey)"
        self.defaults = UserDefaults(suiteName: suiteName!) ?? .standard
    }

    /// For testing with custom UserDefaults
    init(defaults: UserDefaults) {
        self.suiteName = nil
        self.defaults = defaults
    }

    // MARK: - Device ID

    var deviceId: String? {
        get { defaults.string(forKey: SAConstants.StorageKey.deviceId) }
        set { defaults.set(newValue, forKey: SAConstants.StorageKey.deviceId) }
    }

    // MARK: - User ID

    var userId: String? {
        get { defaults.string(forKey: SAConstants.StorageKey.userId) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: SAConstants.StorageKey.userId)
            } else {
                defaults.removeObject(forKey: SAConstants.StorageKey.userId)
            }
        }
    }

    // MARK: - Session

    var sessionId: Int64 {
        get {
            let val = defaults.object(forKey: SAConstants.StorageKey.sessionId) as? NSNumber
            return val?.int64Value ?? 0
        }
        set { defaults.set(NSNumber(value: newValue), forKey: SAConstants.StorageKey.sessionId) }
    }

    var lastEventTime: Int64 {
        get {
            let val = defaults.object(forKey: SAConstants.StorageKey.lastEventTime) as? NSNumber
            return val?.int64Value ?? 0
        }
        set { defaults.set(NSNumber(value: newValue), forKey: SAConstants.StorageKey.lastEventTime) }
    }

    var lastBackgroundTime: Int64 {
        get {
            let val = defaults.object(forKey: SAConstants.StorageKey.lastBackgroundTime) as? NSNumber
            return val?.int64Value ?? 0
        }
        set { defaults.set(NSNumber(value: newValue), forKey: SAConstants.StorageKey.lastBackgroundTime) }
    }

    // MARK: - Event Sequence Counter

    var eventSequence: Int {
        get { defaults.integer(forKey: SAConstants.StorageKey.eventSequence) }
        set { defaults.set(newValue, forKey: SAConstants.StorageKey.eventSequence) }
    }

    func nextEventId() -> Int {
        let next = eventSequence + 1
        eventSequence = next
        return next
    }

    // MARK: - App Version Tracking

    var previousAppVersion: String? {
        get { defaults.string(forKey: SAConstants.StorageKey.previousAppVersion) }
        set { defaults.set(newValue, forKey: SAConstants.StorageKey.previousAppVersion) }
    }

    var previousAppBuild: String? {
        get { defaults.string(forKey: SAConstants.StorageKey.previousAppBuild) }
        set { defaults.set(newValue, forKey: SAConstants.StorageKey.previousAppBuild) }
    }

    var appInstalled: Bool {
        get { defaults.bool(forKey: SAConstants.StorageKey.appInstalled) }
        set { defaults.set(newValue, forKey: SAConstants.StorageKey.appInstalled) }
    }

    // MARK: - Opt Out

    var optOut: Bool {
        get { defaults.bool(forKey: SAConstants.StorageKey.optOut) }
        set { defaults.set(newValue, forKey: SAConstants.StorageKey.optOut) }
    }

    // MARK: - Consent State

    var consentState: SAConsentState {
        get {
            guard let raw = defaults.string(forKey: SAConstants.StorageKey.consentState) else {
                return .unknown
            }
            return SAConsentState(rawValue: raw) ?? .unknown
        }
        set { defaults.set(newValue.rawValue, forKey: SAConstants.StorageKey.consentState) }
    }

    // MARK: - Generic Helpers

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    // MARK: - Reset

    func clearAll() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        } else {
            for key in defaults.dictionaryRepresentation().keys {
                if key.hasPrefix("sa_") {
                    defaults.removeObject(forKey: key)
                }
            }
        }
    }
}
