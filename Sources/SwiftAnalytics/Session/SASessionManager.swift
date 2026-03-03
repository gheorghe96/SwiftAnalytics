import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages session lifecycle: start, end, timeout, and background handling.
final class SASessionManager {

    private let persistence: SAPersistence
    private let minSessionGapMs: Int
    private let trackSessionEvents: Bool
    private let lock = NSLock()

    private(set) var sessionId: Int64 = 0
    private var lastEventTimeMs: Int64 = 0

    /// Called when a session event should be tracked.
    var onSessionEvent: ((SAEvent) -> Void)?

    init(persistence: SAPersistence,
         minTimeBetweenSessionsMillis: Int,
         trackingSessionEvents: Bool) {
        self.persistence = persistence
        self.minSessionGapMs = minTimeBetweenSessionsMillis
        self.trackSessionEvents = trackingSessionEvents

        // Restore session state
        let storedSessionId = persistence.sessionId
        let storedLastEvent = persistence.lastEventTime

        if storedSessionId > 0 {
            self.sessionId = storedSessionId
            self.lastEventTimeMs = storedLastEvent
        }
    }

    // MARK: - Session Lifecycle

    /// Called when app enters foreground or SDK initializes.
    /// Returns true if a new session was started.
    @discardableResult
    func handleForeground() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = currentTimeMs()
        let lastBg = persistence.lastBackgroundTime

        if sessionId == 0 || shouldStartNewSession(now: now, lastBackground: lastBg) {
            return startNewSessionLocked(now: now)
        }

        return false
    }

    /// Called when app enters background.
    func handleBackground() {
        lock.lock()
        defer { lock.unlock() }

        let now = currentTimeMs()
        persistence.lastBackgroundTime = now

        SALogger.debug("Session backgrounded at \(now)")
    }

    /// Call before processing each event to update session state.
    /// Returns true if a new session was started due to timeout.
    @discardableResult
    func touchSession() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = currentTimeMs()

        if sessionId == 0 {
            return startNewSessionLocked(now: now)
        }

        if isSessionExpired(now: now) {
            emitSessionEnd(now: now)
            return startNewSessionLocked(now: now)
        }

        lastEventTimeMs = now
        persistence.lastEventTime = now
        return false
    }

    /// Force start a new session (e.g., after setUserId with startNewSession flag).
    @discardableResult
    func startNewSession() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = currentTimeMs()

        if sessionId > 0 {
            emitSessionEnd(now: now)
        }

        return startNewSessionLocked(now: now)
    }

    /// Get current session ID.
    func getSessionId() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return sessionId
    }

    /// Enrich event with session ID.
    func enrich(event: inout SAEvent) {
        lock.lock()
        defer { lock.unlock() }
        event.sessionId = sessionId
    }

    // MARK: - Private

    private func shouldStartNewSession(now: Int64, lastBackground: Int64) -> Bool {
        guard lastBackground > 0 else { return true }
        let gap = now - lastBackground
        return gap > Int64(minSessionGapMs)
    }

    private func isSessionExpired(now: Int64) -> Bool {
        guard lastEventTimeMs > 0 else { return false }
        let gap = now - lastEventTimeMs
        return gap > Int64(minSessionGapMs)
    }

    @discardableResult
    private func startNewSessionLocked(now: Int64) -> Bool {
        sessionId = now
        lastEventTimeMs = now
        persistence.sessionId = sessionId
        persistence.lastEventTime = now

        SALogger.info("New session started: \(sessionId)")

        if trackSessionEvents {
            var event = SAEvent(eventType: SAConstants.EventType.sessionStart)
            event.sessionId = sessionId
            event.time = now
            onSessionEvent?(event)
        }

        return true
    }

    private func emitSessionEnd(now: Int64) {
        guard trackSessionEvents, sessionId > 0 else { return }

        let durationMs = now - sessionId
        var event = SAEvent(eventType: SAConstants.EventType.sessionEnd)
        event.sessionId = sessionId
        event.time = now
        event.eventProperties = ["session_duration_ms": durationMs]
        onSessionEvent?(event)

        SALogger.info("Session ended: \(sessionId), duration: \(durationMs)ms")
    }

    private func currentTimeMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
