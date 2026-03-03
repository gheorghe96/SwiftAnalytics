#if canImport(UIKit) && canImport(UserNotifications)
import UIKit
import UserNotifications
import Foundation

/// Auto-captures push notification open and receive events.
/// Installs itself as a UNUserNotificationCenter delegate proxy.
final class SAPushNotificationTracker: SAEventPlugin {

    private var originalDelegate: UNUserNotificationCenterDelegate?
    private let delegateProxy = SANotificationDelegateProxy()

    init() {
        super.init(type: .utility)
    }

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        delegateProxy.analytics = analytics
        installDelegateProxy()
    }

    override func teardown() {
        // Restore original delegate
        let center = UNUserNotificationCenter.current()
        if center.delegate === delegateProxy {
            center.delegate = originalDelegate
        }
        super.teardown()
    }

    private func installDelegateProxy() {
        let center = UNUserNotificationCenter.current()

        // Save original delegate and set our proxy
        originalDelegate = center.delegate
        delegateProxy.originalDelegate = originalDelegate
        center.delegate = delegateProxy

        SALogger.info("Push notification tracking installed")
    }
}

// MARK: - Delegate Proxy

/// Proxies UNUserNotificationCenterDelegate calls, tracks events, then forwards to original delegate.
private final class SANotificationDelegateProxy: NSObject, UNUserNotificationCenterDelegate {

    weak var analytics: SwiftAnalytics?
    weak var originalDelegate: UNUserNotificationCenterDelegate?

    // MARK: - Notification Opened (user tapped)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let notification = response.notification
        let content = notification.request.content

        var properties: SAProperties = [
            "notification_id": notification.request.identifier,
            "title": content.title,
            "category": content.categoryIdentifier,
        ]

        if response.actionIdentifier != UNNotificationDefaultActionIdentifier &&
           response.actionIdentifier != UNNotificationDismissActionIdentifier {
            properties["action_id"] = response.actionIdentifier
        }

        analytics?.track(SAConstants.EventType.pushNotificationOpened, eventProperties: properties)

        // Forward to original delegate
        if let original = originalDelegate,
           original.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            original.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }

    // MARK: - Notification Received (foreground)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content

        let properties: SAProperties = [
            "notification_id": notification.request.identifier,
            "title": content.title,
            "category": content.categoryIdentifier,
        ]

        analytics?.track(SAConstants.EventType.pushNotificationReceived, eventProperties: properties)

        // Forward to original delegate
        if let original = originalDelegate,
           original.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            original.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
#endif
