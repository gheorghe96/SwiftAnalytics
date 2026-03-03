import Foundation

/// Fluent builder for constructing SAEvent instances.
public final class SAEventBuilder {
    private var event: SAEvent

    public init(_ eventType: String) {
        self.event = SAEvent(eventType: eventType)
    }

    // MARK: - Property Setters

    @discardableResult
    public func set(_ key: String, _ value: Any) -> SAEventBuilder {
        if event.eventProperties == nil {
            event.eventProperties = [:]
        }
        event.eventProperties?[key] = value
        return self
    }

    @discardableResult
    public func setProperties(_ properties: SAProperties) -> SAEventBuilder {
        if event.eventProperties == nil {
            event.eventProperties = properties
        } else {
            for (key, value) in properties {
                event.eventProperties?[key] = value
            }
        }
        return self
    }

    // MARK: - User Properties

    @discardableResult
    public func setUserProperty(_ key: String, _ value: Any) -> SAEventBuilder {
        if event.userProperties == nil {
            event.userProperties = [:]
        }
        var setOps = (event.userProperties?[SAConstants.IdentifyOp.set] as? SAProperties) ?? [:]
        setOps[key] = value
        event.userProperties?[SAConstants.IdentifyOp.set] = setOps
        return self
    }

    // MARK: - Groups

    @discardableResult
    public func setGroup(_ groupType: String, _ groupName: Any) -> SAEventBuilder {
        if event.groups == nil {
            event.groups = [:]
        }
        event.groups?[groupType] = groupName
        return self
    }

    // MARK: - Timestamps

    @discardableResult
    public func setTime(_ timestampMs: Int64) -> SAEventBuilder {
        event.time = timestampMs
        return self
    }

    // MARK: - Attribution

    @discardableResult
    public func setUTMSource(_ value: String) -> SAEventBuilder {
        event.utmSource = value
        return self
    }

    @discardableResult
    public func setUTMMedium(_ value: String) -> SAEventBuilder {
        event.utmMedium = value
        return self
    }

    @discardableResult
    public func setUTMCampaign(_ value: String) -> SAEventBuilder {
        event.utmCampaign = value
        return self
    }

    // MARK: - Build

    public func build() -> SAEvent {
        return event
    }
}
