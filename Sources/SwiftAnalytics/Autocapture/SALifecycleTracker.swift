#if canImport(UIKit)
import UIKit
import Foundation

/// Tracks app lifecycle events: install, update, open, background.
final class SALifecycleTracker: SAEventPlugin {

    private var persistence: SAPersistence?
    private var deviceInfo: SADeviceInfo?
    private var hasTrackedInstallOrUpdate = false

    init() {
        super.init(type: .utility)
    }

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        self.persistence = analytics.persistence
        self.deviceInfo = analytics.deviceInfo

        // Check for install or update
        checkInstallOrUpdate()

        // Register for lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    override func teardown() {
        NotificationCenter.default.removeObserver(self)
        super.teardown()
    }

    // MARK: - Install / Update Detection

    private func checkInstallOrUpdate() {
        guard let persistence, let deviceInfo else { return }

        let currentVersion = deviceInfo.appVersion
        let currentBuild = deviceInfo.appBuild

        if !persistence.appInstalled {
            // First launch ever — Application Installed
            persistence.appInstalled = true
            persistence.previousAppVersion = currentVersion
            persistence.previousAppBuild = currentBuild

            trackEvent(SAConstants.EventType.applicationInstalled, properties: [
                "version": currentVersion,
                "build": currentBuild
            ])
            hasTrackedInstallOrUpdate = true

        } else {
            let prevVersion = persistence.previousAppVersion
            let prevBuild = persistence.previousAppBuild

            if prevVersion != currentVersion || prevBuild != currentBuild {
                // App updated
                var props: SAProperties = [
                    "version": currentVersion,
                    "build": currentBuild
                ]
                if let prevVersion {
                    props["previous_version"] = prevVersion
                }
                if let prevBuild {
                    props["previous_build"] = prevBuild
                }

                persistence.previousAppVersion = currentVersion
                persistence.previousAppBuild = currentBuild

                trackEvent(SAConstants.EventType.applicationUpdated, properties: props)
                hasTrackedInstallOrUpdate = true
            }
        }
    }

    // MARK: - Lifecycle Notifications

    @objc private func applicationDidBecomeActive() {
        let isFromBackground = persistence?.lastBackgroundTime ?? 0 > 0
        trackEvent(SAConstants.EventType.applicationOpened, properties: [
            "from_background": isFromBackground
        ])
    }

    @objc private func applicationDidEnterBackground() {
        guard let persistence else { return }
        let sessionId = analytics?.sessionManager.getSessionId() ?? 0
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let durationMs = sessionId > 0 ? now - sessionId : 0

        trackEvent(SAConstants.EventType.applicationBackgrounded, properties: [
            "session_duration_ms": durationMs
        ])
    }

    // MARK: - Helpers

    private func trackEvent(_ eventType: String, properties: SAProperties) {
        guard let analytics else { return }
        analytics.track(eventType, eventProperties: properties)
    }
}
#endif
