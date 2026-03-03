import Foundation

/// Per-property disable toggles for privacy control.
/// By default, all properties are tracked. Disable individual properties as needed.
public struct SATrackingOptions {

    // MARK: - Device Properties
    public var trackCarrier: Bool = true
    public var trackDeviceModel: Bool = true
    public var trackIPAddress: Bool = true
    public var trackLanguage: Bool = true
    public var trackOSName: Bool = true
    public var trackOSVersion: Bool = true
    public var trackPlatform: Bool = true
    public var trackScreenSize: Bool = true

    // MARK: - Geo Properties
    public var trackCountry: Bool = true
    public var trackRegion: Bool = true
    public var trackCity: Bool = true
    public var trackDMA: Bool = true

    // MARK: - Identifiers
    public var trackIDFV: Bool = true
    public var trackIDFA: Bool = false  // opt-in only (ATT)

    // MARK: - GPS
    public var trackLatLng: Bool = false  // off by default — requires permission

    // MARK: - Network
    public var trackNetworkType: Bool = true

    // MARK: - Locale
    public var trackTimezone: Bool = true
    public var trackLocale: Bool = true

    public init() {}

    // MARK: - Builder Pattern

    @discardableResult
    public mutating func disableTrackCarrier() -> SATrackingOptions {
        trackCarrier = false; return self
    }

    @discardableResult
    public mutating func disableTrackDeviceModel() -> SATrackingOptions {
        trackDeviceModel = false; return self
    }

    @discardableResult
    public mutating func disableTrackIPAddress() -> SATrackingOptions {
        trackIPAddress = false; return self
    }

    @discardableResult
    public mutating func disableTrackLanguage() -> SATrackingOptions {
        trackLanguage = false; return self
    }

    @discardableResult
    public mutating func disableTrackOSVersion() -> SATrackingOptions {
        trackOSVersion = false; return self
    }

    @discardableResult
    public mutating func disableTrackCountry() -> SATrackingOptions {
        trackCountry = false; return self
    }

    @discardableResult
    public mutating func disableTrackRegion() -> SATrackingOptions {
        trackRegion = false; return self
    }

    @discardableResult
    public mutating func disableTrackCity() -> SATrackingOptions {
        trackCity = false; return self
    }

    @discardableResult
    public mutating func disableTrackDMA() -> SATrackingOptions {
        trackDMA = false; return self
    }

    @discardableResult
    public mutating func disableTrackIDFV() -> SATrackingOptions {
        trackIDFV = false; return self
    }

    @discardableResult
    public mutating func disableTrackLatLng() -> SATrackingOptions {
        trackLatLng = false; return self
    }

    @discardableResult
    public mutating func disableTrackNetworkType() -> SATrackingOptions {
        trackNetworkType = false; return self
    }

    @discardableResult
    public mutating func disableTrackTimezone() -> SATrackingOptions {
        trackTimezone = false; return self
    }

    /// COPPA compliance: disable all identifying properties.
    public static func forCOPPA() -> SATrackingOptions {
        var options = SATrackingOptions()
        options.trackIDFV = false
        options.trackIDFA = false
        options.trackCity = false
        options.trackIPAddress = false
        options.trackLatLng = false
        options.trackDMA = false
        return options
    }
}
