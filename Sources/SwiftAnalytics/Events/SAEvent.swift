import Foundation

public struct SAEvent {

    // MARK: - Identity
    public var userId: String?
    public var deviceId: String = ""
    public var sessionId: Int64 = 0
    public var insertId: String = UUID().uuidString
    public var eventId: Int = 0

    // MARK: - Event
    public var eventType: String
    public var eventProperties: SAProperties?
    public var userProperties: SAProperties?
    public var groups: SAProperties?
    public var groupProperties: SAProperties?

    // MARK: - Timestamps
    public var time: Int64 = 0
    public var clientEventTime: String?
    public var clientUploadTime: String?
    public var serverReceivedTime: String?
    public var serverUploadTime: String?

    // MARK: - Device (auto-populated)
    public var platform: String = SAConstants.platform
    public var osName: String = SAConstants.osName
    public var osVersion: String = ""
    public var deviceModel: String = ""
    public var deviceFamily: String = ""
    public var deviceBrand: String = SAConstants.deviceBrand
    public var screenWidth: Int?
    public var screenHeight: Int?
    public var screenDensity: Double?

    // MARK: - App (auto-populated)
    public var appVersion: String = ""
    public var appBuild: String = ""
    public var library: String = SAConstants.sdkLibrary

    // MARK: - Network (auto-populated)
    public var carrier: String?
    public var networkType: String?
    public var cellularTechnology: String?

    // MARK: - Geographic (server-side resolved)
    public var country: String?
    public var countryCode: String?
    public var region: String?
    public var city: String?
    public var dma: String?

    // MARK: - Optional GPS
    public var locationLat: Double?
    public var locationLng: Double?

    // MARK: - Attribution
    public var utmSource: String?
    public var utmMedium: String?
    public var utmCampaign: String?
    public var utmTerm: String?
    public var utmContent: String?
    public var referrer: String?

    // MARK: - Locale
    public var language: String = ""
    public var locale: String = ""
    public var timezone: String = ""

    // MARK: - Device Identifiers
    public var idfv: String?
    public var idfa: String?

    // MARK: - Internal
    var plan: SAProperties?
    var ip: String?

    // MARK: - Init

    public init(eventType: String, eventProperties: SAProperties? = nil) {
        self.eventType = eventType
        self.eventProperties = eventProperties
        self.time = Int64(Date().timeIntervalSince1970 * 1000)
        self.clientEventTime = ISO8601DateFormatter().string(from: Date())
    }

    // MARK: - JSON Serialization

    /// Convert event to a JSON-compatible dictionary for HTTP upload and SQLite storage.
    public func toJSON() -> [String: Any] {
        var json = [String: Any]()

        // Identity
        if let userId { json["user_id"] = userId }
        json["device_id"] = deviceId
        json["session_id"] = sessionId
        json["insert_id"] = insertId
        json["event_id"] = eventId

        // Event
        json["event_type"] = eventType
        if let eventProperties, !eventProperties.isEmpty {
            json["event_properties"] = SAEvent.sanitizeProperties(eventProperties)
        }
        if let userProperties, !userProperties.isEmpty {
            json["user_properties"] = SAEvent.sanitizeProperties(userProperties)
        }
        if let groups, !groups.isEmpty {
            json["groups"] = SAEvent.sanitizeProperties(groups)
        }
        if let groupProperties, !groupProperties.isEmpty {
            json["group_properties"] = SAEvent.sanitizeProperties(groupProperties)
        }

        // Timestamps
        json["time"] = time
        if let clientEventTime { json["client_event_time"] = clientEventTime }
        if let clientUploadTime { json["client_upload_time"] = clientUploadTime }

        // Device
        json["platform"] = platform
        json["os_name"] = osName
        json["os_version"] = osVersion
        json["device_model"] = deviceModel
        json["device_family"] = deviceFamily
        json["device_brand"] = deviceBrand
        if let screenWidth { json["screen_width"] = screenWidth }
        if let screenHeight { json["screen_height"] = screenHeight }
        if let screenDensity { json["screen_density"] = screenDensity }

        // App
        json["app_version"] = appVersion
        json["app_build"] = appBuild
        json["library"] = library

        // Network
        if let carrier { json["carrier"] = carrier }
        if let networkType { json["network_type"] = networkType }
        if let cellularTechnology { json["cellular_technology"] = cellularTechnology }

        // Geo (typically set server-side, but included if present)
        if let country { json["country"] = country }
        if let countryCode { json["country_code"] = countryCode }
        if let region { json["region"] = region }
        if let city { json["city"] = city }
        if let dma { json["dma"] = dma }

        // GPS
        if let locationLat { json["location_lat"] = locationLat }
        if let locationLng { json["location_lng"] = locationLng }

        // Attribution
        if let utmSource { json["utm_source"] = utmSource }
        if let utmMedium { json["utm_medium"] = utmMedium }
        if let utmCampaign { json["utm_campaign"] = utmCampaign }
        if let utmTerm { json["utm_term"] = utmTerm }
        if let utmContent { json["utm_content"] = utmContent }
        if let referrer { json["referrer"] = referrer }

        // Locale
        json["language"] = language
        json["locale"] = locale
        json["timezone"] = timezone

        // Identifiers
        if let idfv { json["idfv"] = idfv }
        if let idfa { json["idfa"] = idfa }

        // IP (sent to server, server discards after geo lookup)
        if let ip { json["ip"] = ip }

        return json
    }

    /// Serialize the event to JSON Data for storage.
    public func toJSONData() -> Data? {
        let json = toJSON()
        return try? JSONSerialization.data(withJSONObject: json, options: [])
    }

    /// Deserialize an event from a JSON dictionary.
    public static func fromJSON(_ json: [String: Any]) -> SAEvent? {
        guard let eventType = json["event_type"] as? String else { return nil }

        var event = SAEvent(eventType: eventType)

        // Identity
        event.userId = json["user_id"] as? String
        event.deviceId = json["device_id"] as? String ?? ""
        event.sessionId = (json["session_id"] as? NSNumber)?.int64Value ?? 0
        event.insertId = json["insert_id"] as? String ?? UUID().uuidString
        event.eventId = json["event_id"] as? Int ?? 0

        // Event properties
        event.eventProperties = json["event_properties"] as? SAProperties
        event.userProperties = json["user_properties"] as? SAProperties
        event.groups = json["groups"] as? SAProperties
        event.groupProperties = json["group_properties"] as? SAProperties

        // Timestamps
        event.time = (json["time"] as? NSNumber)?.int64Value ?? 0
        event.clientEventTime = json["client_event_time"] as? String
        event.clientUploadTime = json["client_upload_time"] as? String

        // Device
        event.platform = json["platform"] as? String ?? SAConstants.platform
        event.osName = json["os_name"] as? String ?? SAConstants.osName
        event.osVersion = json["os_version"] as? String ?? ""
        event.deviceModel = json["device_model"] as? String ?? ""
        event.deviceFamily = json["device_family"] as? String ?? ""
        event.deviceBrand = json["device_brand"] as? String ?? SAConstants.deviceBrand
        event.screenWidth = json["screen_width"] as? Int
        event.screenHeight = json["screen_height"] as? Int
        event.screenDensity = json["screen_density"] as? Double

        // App
        event.appVersion = json["app_version"] as? String ?? ""
        event.appBuild = json["app_build"] as? String ?? ""
        event.library = json["library"] as? String ?? SAConstants.sdkLibrary

        // Network
        event.carrier = json["carrier"] as? String
        event.networkType = json["network_type"] as? String
        event.cellularTechnology = json["cellular_technology"] as? String

        // Geo
        event.country = json["country"] as? String
        event.countryCode = json["country_code"] as? String
        event.region = json["region"] as? String
        event.city = json["city"] as? String
        event.dma = json["dma"] as? String

        // GPS
        event.locationLat = json["location_lat"] as? Double
        event.locationLng = json["location_lng"] as? Double

        // Attribution
        event.utmSource = json["utm_source"] as? String
        event.utmMedium = json["utm_medium"] as? String
        event.utmCampaign = json["utm_campaign"] as? String
        event.utmTerm = json["utm_term"] as? String
        event.utmContent = json["utm_content"] as? String
        event.referrer = json["referrer"] as? String

        // Locale
        event.language = json["language"] as? String ?? ""
        event.locale = json["locale"] as? String ?? ""
        event.timezone = json["timezone"] as? String ?? ""

        // Identifiers
        event.idfv = json["idfv"] as? String
        event.idfa = json["idfa"] as? String

        return event
    }

    /// Deserialize an event from JSON Data.
    public static func fromJSONData(_ data: Data) -> SAEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return fromJSON(json)
    }

    // MARK: - Helpers

    /// Ensure all values in properties dict are JSON-serializable.
    static func sanitizeProperties(_ properties: SAProperties) -> SAProperties {
        var sanitized = SAProperties()
        for (key, value) in properties {
            if let val = sanitizeValue(value) {
                sanitized[key] = val
            }
        }
        return sanitized
    }

    private static func sanitizeValue(_ value: Any) -> Any? {
        switch value {
        case let str as String: return str
        case let num as NSNumber: return num
        case let bool as Bool: return bool
        case let arr as [Any]: return arr.compactMap { sanitizeValue($0) }
        case let dict as [String: Any]: return sanitizeProperties(dict)
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        case is NSNull: return nil
        default:
            SALogger.warn("Unsupported property value type: \(type(of: value)), skipping")
            return nil
        }
    }
}
