import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages user identity: device_id, user_id, and the event sequence counter.
final class SAIdentityManager {

    private let persistence: SAPersistence
    private let lock = NSLock()

    private(set) var deviceId: String
    private(set) var userId: String?

    init(persistence: SAPersistence) {
        self.persistence = persistence

        // Resolve device ID
        self.deviceId = SAIdentityManager.resolveDeviceId(persistence: persistence)

        // Load user ID
        self.userId = persistence.userId
    }

    // MARK: - Device ID Resolution

    /// Resolution order per spec:
    /// 1. Previously persisted device_id in UserDefaults
    /// 2. IDFV (UIDevice.identifierForVendor) — no permission required
    /// 3. Random UUID v4
    private static func resolveDeviceId(persistence: SAPersistence) -> String {
        // Priority 1: Previously persisted
        if let stored = persistence.deviceId, !stored.isEmpty {
            return stored
        }

        // Priority 2: IDFV
        #if canImport(UIKit)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            persistence.deviceId = idfv
            return idfv
        }
        #endif

        // Priority 3: Random UUID
        let uuid = UUID().uuidString
        persistence.deviceId = uuid
        return uuid
    }

    // MARK: - User ID

    func setUserId(_ userId: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.userId = userId
        persistence.userId = userId
        SALogger.debug("User ID set to: \(userId ?? "nil")")
    }

    // MARK: - Device ID (manual override)

    func setDeviceId(_ deviceId: String) {
        lock.lock()
        defer { lock.unlock() }
        self.deviceId = deviceId
        persistence.deviceId = deviceId
        SALogger.debug("Device ID set to: \(deviceId)")
    }

    // MARK: - Event Sequence

    func nextEventId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return persistence.nextEventId()
    }

    // MARK: - Reset

    /// Hard reset: new device_id, clear user_id
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        let newDeviceId = UUID().uuidString
        self.deviceId = newDeviceId
        self.userId = nil

        persistence.deviceId = newDeviceId
        persistence.userId = nil
        persistence.eventSequence = 0

        SALogger.info("Identity reset. New device_id: \(newDeviceId)")
    }

    // MARK: - Enrich Event

    func enrich(event: inout SAEvent) {
        lock.lock()
        defer { lock.unlock() }

        event.userId = userId
        event.deviceId = deviceId
        event.eventId = persistence.nextEventId()
    }
}
