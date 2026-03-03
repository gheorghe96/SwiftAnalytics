import Foundation

public final class SAConfiguration {

    // MARK: - Required
    public let apiKey: String
    public let serverURL: URL

    // MARK: - Flush / Upload
    public var flushIntervalMillis: Int
    public var flushQueueSize: Int
    public var maxQueueDepth: Int
    public var maxBatchSizeBytes: Int
    public var uploadRetryCount: Int
    public var flushOnBackground: Bool
    public var uploadOnWifiOnly: Bool

    // MARK: - Sessions
    public var minTimeBetweenSessionsMillis: Int
    public var trackingSessionEvents: Bool

    // MARK: - Autocapture
    public var autocapture: SAAutocaptureOptions

    // MARK: - Location
    public var locationTracking: SALocationTracking

    // MARK: - Identity
    public var enableCoppaControl: Bool
    public var minIdLength: Int

    // MARK: - Privacy
    public var optOut: Bool
    public var trackingOptions: SATrackingOptions

    // MARK: - Logging
    public var logLevel: SALogLevel

    // MARK: - Advanced
    public var enableSessionReplay: Bool
    public var enableRealtime: Bool
    public var realtimeURL: URL?
    public var useBatch: Bool

    // MARK: - Plugins
    public var defaultPluginsEnabled: Bool

    // MARK: - Init
    public init(
        apiKey: String,
        serverURL: URL,
        flushIntervalMillis: Int = SAConstants.Defaults.flushIntervalMillis,
        flushQueueSize: Int = SAConstants.Defaults.flushQueueSize,
        maxQueueDepth: Int = SAConstants.Defaults.maxQueueDepth,
        maxBatchSizeBytes: Int = SAConstants.Defaults.maxBatchSizeBytes,
        uploadRetryCount: Int = SAConstants.Defaults.uploadRetryCount,
        flushOnBackground: Bool = true,
        uploadOnWifiOnly: Bool = false,
        minTimeBetweenSessionsMillis: Int = SAConstants.Defaults.minTimeBetweenSessionsMillis,
        trackingSessionEvents: Bool = true,
        autocapture: SAAutocaptureOptions = .all,
        locationTracking: SALocationTracking = .disabled,
        enableCoppaControl: Bool = false,
        minIdLength: Int = 5,
        optOut: Bool = false,
        trackingOptions: SATrackingOptions = SATrackingOptions(),
        logLevel: SALogLevel = .warn,
        enableSessionReplay: Bool = false,
        enableRealtime: Bool = false,
        realtimeURL: URL? = nil,
        useBatch: Bool = true,
        defaultPluginsEnabled: Bool = true
    ) {
        self.apiKey = apiKey
        self.serverURL = serverURL
        self.flushIntervalMillis = flushIntervalMillis
        self.flushQueueSize = flushQueueSize
        self.maxQueueDepth = maxQueueDepth
        self.maxBatchSizeBytes = maxBatchSizeBytes
        self.uploadRetryCount = uploadRetryCount
        self.flushOnBackground = flushOnBackground
        self.uploadOnWifiOnly = uploadOnWifiOnly
        self.minTimeBetweenSessionsMillis = minTimeBetweenSessionsMillis
        self.trackingSessionEvents = trackingSessionEvents
        self.autocapture = autocapture
        self.locationTracking = locationTracking
        self.enableCoppaControl = enableCoppaControl
        self.minIdLength = minIdLength
        self.optOut = optOut
        self.trackingOptions = trackingOptions
        self.logLevel = logLevel
        self.enableSessionReplay = enableSessionReplay
        self.enableRealtime = enableRealtime
        self.realtimeURL = realtimeURL
        self.useBatch = useBatch
        self.defaultPluginsEnabled = defaultPluginsEnabled
    }

    /// Convenience initializer with string URL
    public convenience init(
        apiKey: String,
        serverURL: String,
        flushIntervalMillis: Int = SAConstants.Defaults.flushIntervalMillis,
        flushQueueSize: Int = SAConstants.Defaults.flushQueueSize,
        maxQueueDepth: Int = SAConstants.Defaults.maxQueueDepth,
        maxBatchSizeBytes: Int = SAConstants.Defaults.maxBatchSizeBytes,
        uploadRetryCount: Int = SAConstants.Defaults.uploadRetryCount,
        flushOnBackground: Bool = true,
        uploadOnWifiOnly: Bool = false,
        minTimeBetweenSessionsMillis: Int = SAConstants.Defaults.minTimeBetweenSessionsMillis,
        trackingSessionEvents: Bool = true,
        autocapture: SAAutocaptureOptions = .all,
        locationTracking: SALocationTracking = .disabled,
        enableCoppaControl: Bool = false,
        minIdLength: Int = 5,
        optOut: Bool = false,
        trackingOptions: SATrackingOptions = SATrackingOptions(),
        logLevel: SALogLevel = .warn,
        enableSessionReplay: Bool = false,
        enableRealtime: Bool = false,
        realtimeURL: URL? = nil,
        useBatch: Bool = true,
        defaultPluginsEnabled: Bool = true
    ) {
        guard let url = URL(string: serverURL) else {
            fatalError("[SwiftAnalytics] Invalid server URL: \(serverURL)")
        }
        self.init(
            apiKey: apiKey,
            serverURL: url,
            flushIntervalMillis: flushIntervalMillis,
            flushQueueSize: flushQueueSize,
            maxQueueDepth: maxQueueDepth,
            maxBatchSizeBytes: maxBatchSizeBytes,
            uploadRetryCount: uploadRetryCount,
            flushOnBackground: flushOnBackground,
            uploadOnWifiOnly: uploadOnWifiOnly,
            minTimeBetweenSessionsMillis: minTimeBetweenSessionsMillis,
            trackingSessionEvents: trackingSessionEvents,
            autocapture: autocapture,
            locationTracking: locationTracking,
            enableCoppaControl: enableCoppaControl,
            minIdLength: minIdLength,
            optOut: optOut,
            trackingOptions: trackingOptions,
            logLevel: logLevel,
            enableSessionReplay: enableSessionReplay,
            enableRealtime: enableRealtime,
            realtimeURL: realtimeURL,
            useBatch: useBatch,
            defaultPluginsEnabled: defaultPluginsEnabled
        )
    }
}
