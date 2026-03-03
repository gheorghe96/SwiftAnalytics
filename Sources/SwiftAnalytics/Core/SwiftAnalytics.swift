import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// SwiftAnalytics — Self-hosted iOS analytics SDK.
/// Full Amplitude feature parity with zero external dependencies.
public final class SwiftAnalytics {

    // MARK: - Singleton

    /// Shared instance (set after `initialize(configuration:)`).
    public private(set) static var shared: SwiftAnalytics?

    // MARK: - Internal Components

    let configuration: SAConfiguration
    let persistence: SAPersistence
    let identityManager: SAIdentityManager
    let sessionManager: SASessionManager
    let deviceInfo: SADeviceInfo
    let eventStore: SAEventStore
    let uploader: SAUploader
    let groupManager: SAGroupManager
    let timeline: SATimeline

    /// Consent manager — public for direct access.
    public let consentManager: SAConsentManager

    /// Realtime client — public for subscribing to live metrics.
    public private(set) var realtimeClient: SARealtimeClient?

    private let sdkQueue = DispatchQueue(label: "com.swiftanalytics.sdk", qos: .utility)
    private var isInitialized = false

    // MARK: - Initialization

    /// Initialize the SDK. This is the primary entry point.
    @discardableResult
    public static func initialize(configuration: SAConfiguration) -> SwiftAnalytics {
        let instance = SwiftAnalytics(configuration: configuration)
        shared = instance
        return instance
    }

    /// Create a named instance (for multi-project or testing).
    public init(configuration: SAConfiguration) {
        self.configuration = configuration

        // Set log level
        SALogger.logLevel = configuration.logLevel

        // Initialize persistence
        self.persistence = SAPersistence(apiKey: configuration.apiKey)

        // Initialize identity
        self.identityManager = SAIdentityManager(persistence: persistence)

        // Initialize device info
        self.deviceInfo = SADeviceInfo()

        // Initialize session manager
        self.sessionManager = SASessionManager(
            persistence: persistence,
            minTimeBetweenSessionsMillis: configuration.minTimeBetweenSessionsMillis,
            trackingSessionEvents: configuration.trackingSessionEvents
        )

        // Initialize storage
        self.eventStore = SAEventStore(apiKey: configuration.apiKey)

        // Initialize uploader
        self.uploader = SAUploader(configuration: configuration, eventStore: eventStore)

        // Initialize group manager
        self.groupManager = SAGroupManager()

        // Initialize consent manager
        self.consentManager = SAConsentManager(persistence: persistence)

        // Initialize plugin timeline
        self.timeline = SATimeline()

        // Check initial opt-out state
        if configuration.optOut {
            consentManager.optOut()
        }

        // Setup
        setup()
    }

    // MARK: - Setup

    private func setup() {
        // Wire session events back through the pipeline
        sessionManager.onSessionEvent = { [weak self] event in
            self?.processEvent(event)
        }

        // Start first session
        sessionManager.handleForeground()

        // Setup plugin pipeline
        timeline.analytics = self

        if configuration.defaultPluginsEnabled {
            setupDefaultPlugins()
        }

        // Setup autocapture
        setupAutocapture()

        // Start network monitoring
        if configuration.autocapture.contains(.networkType) {
            deviceInfo.startNetworkMonitoring()
        }

        // Start uploader
        uploader.start()

        // Trim event queue
        eventStore.trimToSize(configuration.maxQueueDepth)

        // Setup realtime client if enabled
        if configuration.enableRealtime, let realtimeURL = configuration.realtimeURL {
            realtimeClient = SARealtimeClient(serverURL: realtimeURL, apiKey: configuration.apiKey)
        }

        // Register for app lifecycle (session management)
        registerLifecycleObservers()

        isInitialized = true
        SALogger.info("SwiftAnalytics initialized — device_id: \(identityManager.deviceId)")
    }

    private func setupDefaultPlugins() {
        // Consent gate (runs first)
        timeline.add(plugin: SAConsentPlugin(consentManager: consentManager))

        // Context enrichment (device info, identity, session)
        timeline.add(plugin: SAContextPlugin())

        // Destination (SQLite → HTTP upload)
        timeline.add(plugin: SAAmplitudeDestinationPlugin())
    }

    private func setupAutocapture() {
        #if canImport(UIKit)
        let opts = configuration.autocapture

        if opts.contains(.appLifecycle) {
            timeline.add(plugin: SALifecycleTracker())
        }

        if opts.contains(.screenViews) {
            timeline.add(plugin: SAScreenTracker())
        }

        if opts.contains(.deepLinks) {
            timeline.add(plugin: SADeepLinkTracker())
        }

        if opts.contains(.crashes) {
            timeline.add(plugin: SACrashTracker())
        }
        #endif
    }

    private func registerLifecycleObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif
    }

    #if canImport(UIKit)
    @objc private func appDidBecomeActive() {
        sdkQueue.async { [weak self] in
            self?.sessionManager.handleForeground()
        }
    }

    @objc private func appDidEnterBackground() {
        sdkQueue.async { [weak self] in
            guard let self else { return }
            self.sessionManager.handleBackground()
            if self.configuration.flushOnBackground {
                self.uploader.flush()
            }
        }
    }
    #endif

    // MARK: - Track Events

    /// Track a custom event.
    public func track(_ eventType: String, eventProperties: SAProperties? = nil) {
        let event = SAEvent(eventType: eventType, eventProperties: eventProperties)
        processEvent(event)
    }

    /// Track a pre-built event.
    public func track(_ event: SAEvent) {
        processEvent(event)
    }

    /// Track with upload completion callback.
    public func track(_ eventType: String, eventProperties: SAProperties? = nil,
                      callback: @escaping SAUploadCallback) {
        let event = SAEvent(eventType: eventType, eventProperties: eventProperties)
        // Store callback for when this event's batch uploads
        uploader.onUploadComplete = { result in
            switch result {
            case .success: callback(.success(()))
            case .failure(let err): callback(.failure(err))
            }
        }
        processEvent(event)
    }

    // MARK: - Identify

    /// Send an identify event to update user properties.
    public func identify(identify: SAIdentify) {
        guard !identify.isEmpty else {
            SALogger.warn("Empty identify — skipping")
            return
        }

        var event = SAEvent(eventType: SAConstants.EventType.identify)
        event.userProperties = identify.toUserProperties()
        processEvent(event)
    }

    /// Set user ID and send identify operations simultaneously.
    public func identify(userId: String, identify: SAIdentify) {
        setUserId(userId)
        self.identify(identify: identify)
    }

    // MARK: - Revenue

    /// Log a revenue event.
    public func logRevenue(_ revenue: SARevenue) {
        guard revenue.isValid else {
            SALogger.warn("Invalid revenue event (price = 0)")
            return
        }

        let event = revenue.toEvent()
        processEvent(event)
    }

    // MARK: - User Identity

    /// Set the user ID (call after login).
    public func setUserId(_ userId: String?, startNewSession: Bool = false) {
        sdkQueue.async { [weak self] in
            self?.identityManager.setUserId(userId)
            if startNewSession {
                self?.sessionManager.startNewSession()
            }
        }
    }

    /// Get the current user ID.
    public func getUserId() -> String? {
        identityManager.userId
    }

    /// Get the current device ID.
    public func getDeviceId() -> String {
        identityManager.deviceId
    }

    /// Get the current session ID.
    public func getSessionId() -> Int64 {
        sessionManager.getSessionId()
    }

    /// Override the device ID (for cross-platform sync).
    public func setDeviceId(_ deviceId: String) {
        sdkQueue.async { [weak self] in
            self?.identityManager.setDeviceId(deviceId)
        }
    }

    /// Hard reset: new device_id, clear user_id and all state.
    public func reset() {
        sdkQueue.async { [weak self] in
            self?.identityManager.reset()
            self?.sessionManager.startNewSession()
            self?.groupManager.clearGroups()
        }
    }

    // MARK: - Groups

    /// Set a group assignment.
    public func setGroup(groupType: String, groupName: Any) {
        sdkQueue.async { [weak self] in
            self?.groupManager.setGroup(groupType: groupType, groupName: groupName)
        }
    }

    /// Set properties on a group.
    public func groupIdentify(groupType: String, groupName: String, identify: SAIdentify) {
        let event = groupManager.createGroupIdentifyEvent(
            groupType: groupType,
            groupName: groupName,
            identify: identify
        )
        processEvent(event)
    }

    // MARK: - Plugin Management

    /// Add a custom plugin to the pipeline.
    public func add(plugin: SAPlugin) {
        timeline.add(plugin: plugin)
    }

    /// Remove a plugin.
    public func remove(plugin: SAPlugin) {
        timeline.remove(plugin: plugin)
    }

    /// Find a plugin by type.
    public func find<T: SAPlugin>(pluginType: T.Type) -> T? {
        timeline.find(pluginType: pluginType)
    }

    // MARK: - Flush

    /// Manually trigger a flush of pending events.
    public func flush() {
        uploader.flush()
    }

    // MARK: - Opt Out

    /// Opt the user out of all tracking.
    public func optOut() {
        consentManager.optOut()
    }

    /// Opt the user back in.
    public func optIn() {
        consentManager.optIn()
    }

    /// Whether the user is currently opted out.
    public var isOptedOut: Bool {
        consentManager.isOptedOut
    }

    // MARK: - Deep Links (convenience for AppDelegate/SceneDelegate)

    /// Call from `application(_:open:options:)` to track deep links.
    public func trackDeepLink(url: URL, sourceApplication: String? = nil) {
        #if canImport(UIKit)
        SADeepLinkTracker.trackDeepLink(url: url, sourceApplication: sourceApplication)
        #endif
    }

    // MARK: - Shutdown

    /// Gracefully shut down the SDK.
    public func shutdown() {
        SALogger.info("SwiftAnalytics shutting down")
        uploader.shutdown()
        deviceInfo.stopNetworkMonitoring()
        realtimeClient?.disconnect()
        timeline.teardownAll()
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    deinit {
        shutdown()
    }

    // MARK: - Internal

    /// Process an event through the plugin pipeline.
    func processEvent(_ event: SAEvent) {
        sdkQueue.async { [weak self] in
            guard let self else { return }

            // Touch session (may start new session if expired)
            self.sessionManager.touchSession()

            // Run through plugin pipeline
            self.timeline.process(event: event)
        }
    }
}
