import Foundation

/// Manages the plugin pipeline: before → enrichment → destination.
/// Events flow through plugins in type order.
final class SATimeline {

    private var plugins: [SAPluginType: [SAPlugin]] = [
        .before: [],
        .enrichment: [],
        .destination: [],
        .utility: [],
    ]

    private let lock = NSLock()
    weak var analytics: SwiftAnalytics?

    // MARK: - Plugin Management

    func add(plugin: SAPlugin) {
        lock.lock()
        defer { lock.unlock() }

        plugin.analytics = analytics
        if let analytics {
            plugin.setup(analytics: analytics)
        }
        plugins[plugin.type, default: []].append(plugin)

        SALogger.debug("Plugin added: \(String(describing: type(of: plugin))) [\(plugin.type)]")
    }

    func remove(plugin: SAPlugin) {
        lock.lock()
        defer { lock.unlock() }

        plugin.teardown()
        plugins[plugin.type]?.removeAll { $0 === plugin }
    }

    func setupAll(analytics: SwiftAnalytics) {
        lock.lock()
        let allPlugins = plugins.values.flatMap { $0 }
        lock.unlock()

        self.analytics = analytics
        for plugin in allPlugins {
            plugin.analytics = analytics
            plugin.setup(analytics: analytics)
        }
    }

    func teardownAll() {
        lock.lock()
        let allPlugins = plugins.values.flatMap { $0 }
        lock.unlock()

        for plugin in allPlugins {
            plugin.teardown()
        }
    }

    // MARK: - Event Processing

    /// Run an event through the full pipeline: before → enrichment → destination.
    /// Returns nil if the event was filtered out.
    @discardableResult
    func process(event: SAEvent) -> SAEvent? {
        lock.lock()
        let beforePlugins = plugins[.before] ?? []
        let enrichPlugins = plugins[.enrichment] ?? []
        let destPlugins = plugins[.destination] ?? []
        lock.unlock()

        // Phase 1: Before plugins (can filter/modify)
        var currentEvent: SAEvent? = event
        for plugin in beforePlugins {
            guard let e = currentEvent else { return nil }
            currentEvent = plugin.execute(event: e)
        }

        // Phase 2: Enrichment plugins (add device, session, etc.)
        for plugin in enrichPlugins {
            guard let e = currentEvent else { return nil }
            currentEvent = plugin.execute(event: e)
        }

        // Phase 3: Destination plugins (store, upload, etc.)
        guard let enrichedEvent = currentEvent else { return nil }
        for plugin in destPlugins {
            _ = plugin.execute(event: enrichedEvent)
        }

        return enrichedEvent
    }

    // MARK: - Query

    /// Find a plugin by type.
    func find<T: SAPlugin>(pluginType: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        for group in plugins.values {
            for plugin in group {
                if let match = plugin as? T {
                    return match
                }
            }
        }
        return nil
    }

    /// Get all plugins of a given type.
    func plugins(ofType type: SAPluginType) -> [SAPlugin] {
        lock.lock()
        defer { lock.unlock() }
        return plugins[type] ?? []
    }
}
