import Foundation

// MARK: - Plugin Type

public enum SAPluginType: Int, Comparable {
    case before = 0       // Runs first — can modify/filter events
    case enrichment = 1   // Adds context data (device info, session, etc.)
    case destination = 2  // Sends events to storage/network
    case utility = 3      // Doesn't process events directly (e.g., crash tracker)

    public static func < (lhs: SAPluginType, rhs: SAPluginType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Plugin Protocol

public protocol SAPlugin: AnyObject {
    /// The type of this plugin (determines execution order).
    var type: SAPluginType { get }

    /// Reference to the analytics instance (set during setup).
    var analytics: SwiftAnalytics? { get set }

    /// Called when the plugin is added to the analytics instance.
    func setup(analytics: SwiftAnalytics)

    /// Process an event. Return nil to drop the event from the pipeline.
    func execute(event: SAEvent) -> SAEvent?

    /// Called when the analytics instance is shut down.
    func teardown()
}

// MARK: - Default Implementations

public extension SAPlugin {
    func setup(analytics: SwiftAnalytics) {
        self.analytics = analytics
    }

    func execute(event: SAEvent) -> SAEvent? {
        return event
    }

    func teardown() {
        analytics = nil
    }
}

// MARK: - Event Plugin (convenience base class)

/// Base class for plugins that process events. Subclass and override as needed.
open class SAEventPlugin: SAPlugin {
    public var type: SAPluginType
    public weak var analytics: SwiftAnalytics?

    public init(type: SAPluginType = .enrichment) {
        self.type = type
    }

    open func setup(analytics: SwiftAnalytics) {
        self.analytics = analytics
    }

    open func execute(event: SAEvent) -> SAEvent? {
        return event
    }

    open func teardown() {
        analytics = nil
    }
}

// MARK: - Destination Plugin (base class for output destinations)

/// Base class for plugins that send events to an external destination.
/// Has its own sub-timeline for pre-processing events before sending.
open class SADestinationPlugin: SAPlugin {
    public let type: SAPluginType = .destination
    public weak var analytics: SwiftAnalytics?

    /// Sub-timeline for destination-specific enrichment
    internal let timeline = SATimeline()

    public init() {}

    open func setup(analytics: SwiftAnalytics) {
        self.analytics = analytics
        timeline.analytics = analytics
    }

    open func execute(event: SAEvent) -> SAEvent? {
        // Run through destination's own sub-timeline first
        let processedEvent = timeline.process(event: event)
        if let processedEvent {
            send(event: processedEvent)
        }
        return processedEvent
    }

    /// Override this to implement the actual sending logic.
    open func send(event: SAEvent) {
        // Subclasses override
    }

    open func teardown() {
        analytics = nil
    }

    /// Add a plugin to this destination's sub-timeline.
    public func add(plugin: SAPlugin) {
        timeline.add(plugin: plugin)
    }
}
