import Foundation

/// Destination plugin that writes events to SQLite and triggers batch upload.
final class SAAmplitudeDestinationPlugin: SADestinationPlugin {

    private var eventStore: SAEventStore?
    private var uploader: SAUploader?

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        self.eventStore = analytics.eventStore
        self.uploader = analytics.uploader
    }

    override func send(event: SAEvent) {
        guard let eventStore else {
            SALogger.error("Event store not available")
            return
        }

        // Write to SQLite first (offline-safe)
        eventStore.insert(event: event)

        // Check if we should trigger a flush
        eventStore.pendingCount { [weak self] count in
            guard let analytics = self?.analytics else { return }
            if count >= analytics.configuration.flushQueueSize {
                self?.uploader?.flush()
            }
        }
    }

    override func teardown() {
        uploader?.shutdown()
        super.teardown()
    }
}
