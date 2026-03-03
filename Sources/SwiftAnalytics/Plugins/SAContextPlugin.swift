import Foundation

/// Enrichment plugin that automatically adds device, identity, and session context to every event.
final class SAContextPlugin: SAEventPlugin {

    init() {
        super.init(type: .enrichment)
    }

    override func execute(event: SAEvent) -> SAEvent? {
        guard let analytics else { return event }

        var enrichedEvent = event

        // Enrich with identity (user_id, device_id, event_id)
        analytics.identityManager.enrich(event: &enrichedEvent)

        // Enrich with session
        analytics.sessionManager.enrich(event: &enrichedEvent)

        // Enrich with device info
        analytics.deviceInfo.enrich(
            event: &enrichedEvent,
            trackingOptions: analytics.configuration.trackingOptions
        )

        // Enrich with group context
        let groups = analytics.groupManager.currentGroups
        if !groups.isEmpty {
            if enrichedEvent.groups == nil {
                enrichedEvent.groups = groups
            } else {
                for (key, value) in groups {
                    enrichedEvent.groups?[key] = value
                }
            }
        }

        return enrichedEvent
    }
}
