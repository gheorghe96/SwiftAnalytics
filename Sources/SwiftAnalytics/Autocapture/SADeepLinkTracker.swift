#if canImport(UIKit)
import UIKit
import Foundation

/// Tracks deep link and universal link opens.
final class SADeepLinkTracker: SAEventPlugin {

    init() {
        super.init(type: .utility)
    }

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)

        // Listen for URL open events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenURL(_:)),
            name: Notification.Name("SADeepLinkOpened"),
            object: nil
        )
    }

    override func teardown() {
        NotificationCenter.default.removeObserver(self)
        super.teardown()
    }

    // MARK: - Public API (called by host app's SceneDelegate/AppDelegate)

    /// Call this from your AppDelegate or SceneDelegate when a URL is opened.
    static func trackDeepLink(url: URL, sourceApplication: String? = nil) {
        var properties: SAProperties = [
            "url": url.absoluteString,
            "link_type": url.scheme?.hasPrefix("http") == true ? "universal_link" : "url_scheme"
        ]

        if let source = sourceApplication {
            properties["referring_application"] = source
        }

        // Extract UTM parameters if present
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                switch item.name {
                case "utm_source":   properties["utm_source"] = item.value
                case "utm_medium":   properties["utm_medium"] = item.value
                case "utm_campaign": properties["utm_campaign"] = item.value
                case "utm_term":     properties["utm_term"] = item.value
                case "utm_content":  properties["utm_content"] = item.value
                default: break
                }
            }
        }

        SwiftAnalytics.shared?.track(SAConstants.EventType.deepLinkOpened, eventProperties: properties)

        // Post notification for internal tracking
        NotificationCenter.default.post(
            name: Notification.Name("SADeepLinkOpened"),
            object: nil,
            userInfo: ["url": url]
        )
    }

    @objc private func handleOpenURL(_ notification: Notification) {
        // Already tracked via static method
    }
}
#endif
