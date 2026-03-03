import Foundation

public enum SAConstants {
    public static let sdkVersion = "3.0.0"
    public static let sdkLibrary = "swift-analytics/\(sdkVersion)"
    public static let platform = "iOS"
    public static let osName = "ios"
    public static let deviceBrand = "Apple"

    // MARK: - Event Prefixes
    public static let autoEventPrefix = "[SA] "

    // MARK: - Auto-Captured Event Names
    public enum EventType {
        public static let applicationInstalled = "[SA] Application Installed"
        public static let applicationUpdated = "[SA] Application Updated"
        public static let applicationOpened = "[SA] Application Opened"
        public static let applicationBackgrounded = "[SA] Application Backgrounded"
        public static let applicationCrashed = "[SA] Application Crashed"
        public static let sessionStart = "[SA] Session Start"
        public static let sessionEnd = "[SA] Session End"
        public static let screenViewed = "[SA] Screen Viewed"
        public static let deepLinkOpened = "[SA] Deep Link Opened"
        public static let pushNotificationOpened = "[SA] Push Notification Opened"
        public static let pushNotificationReceived = "[SA] Push Notification Received"
        public static let revenue = "$revenue"
        public static let identify = "$identify"
        public static let groupIdentify = "$groupidentify"
    }

    // MARK: - Revenue Property Keys
    public enum RevenueKey {
        public static let productId = "$productId"
        public static let price = "$price"
        public static let quantity = "$quantity"
        public static let revenue = "$revenue"
        public static let revenueType = "$revenueType"
        public static let currency = "$currency"
        public static let receipt = "$receipt"
        public static let receiptType = "$receiptType"
    }

    // MARK: - Identify Operation Keys
    public enum IdentifyOp {
        public static let set = "$set"
        public static let setOnce = "$setOnce"
        public static let add = "$add"
        public static let append = "$append"
        public static let prepend = "$prepend"
        public static let postInsert = "$postInsert"
        public static let preInsert = "$preInsert"
        public static let remove = "$remove"
        public static let unset = "$unset"
        public static let clearAll = "$clearAll"
    }

    // MARK: - Storage Keys
    public enum StorageKey {
        public static let deviceId = "sa_device_id"
        public static let userId = "sa_user_id"
        public static let sessionId = "sa_session_id"
        public static let lastEventTime = "sa_last_event_time"
        public static let lastBackgroundTime = "sa_last_background_time"
        public static let eventSequence = "sa_event_sequence"
        public static let previousAppVersion = "sa_previous_app_version"
        public static let previousAppBuild = "sa_previous_app_build"
        public static let appInstalled = "sa_app_installed"
        public static let optOut = "sa_opt_out"
        public static let consentState = "sa_consent_state"
    }

    // MARK: - HTTP
    public enum HTTP {
        public static let defaultEndpoint = "/2/httpapi"
        public static let contentTypeJSON = "application/json"
        public static let contentEncodingGzip = "gzip"
    }

    // MARK: - Defaults
    public enum Defaults {
        public static let flushIntervalMillis: Int = 30_000
        public static let flushQueueSize: Int = 30
        public static let maxQueueDepth: Int = 1_000
        public static let maxBatchSizeBytes: Int = 2_097_152 // 2MB
        public static let uploadRetryCount: Int = 5
        public static let minTimeBetweenSessionsMillis: Int = 300_000 // 5 min
    }
}
