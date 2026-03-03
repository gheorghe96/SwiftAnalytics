#if canImport(UIKit) && canImport(BackgroundTasks)
import UIKit
import BackgroundTasks
import Foundation

/// Registers BGProcessingTask for reliable background event upload.
/// The host app must register the task identifier in Info.plist under
/// `BGTaskSchedulerPermittedIdentifiers`: `com.swiftanalytics.upload`
///
/// Host app must call `SABackgroundTaskManager.registerTasks()` in
/// `application(_:didFinishLaunchingWithOptions:)` BEFORE the app finishes launching.
public final class SABackgroundTaskManager {

    public static let uploadTaskIdentifier = "com.swiftanalytics.upload"

    private weak var analytics: SwiftAnalytics?
    private var isRegistered = false

    init(analytics: SwiftAnalytics) {
        self.analytics = analytics
    }

    // MARK: - Registration

    /// Register the background task with the system.
    /// Must be called in `application(_:didFinishLaunchingWithOptions:)`.
    public func registerTasks() {
        guard !isRegistered else { return }
        isRegistered = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SABackgroundTaskManager.uploadTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            self?.handleBackgroundUpload(task: task)
        }

        SALogger.info("Background task registered: \(SABackgroundTaskManager.uploadTaskIdentifier)")
    }

    /// Schedule the next background upload. Called when app enters background.
    func scheduleBackgroundUpload() {
        let request = BGProcessingTaskRequest(identifier: SABackgroundTaskManager.uploadTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        // Allow up to 1 hour before expiring
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            SALogger.debug("Background upload task scheduled")
        } catch {
            SALogger.warn("Failed to schedule background upload: \(error.localizedDescription)")
        }
    }

    // MARK: - Task Handling

    private func handleBackgroundUpload(task: BGProcessingTask) {
        SALogger.info("Background upload task started")

        // Schedule the next background task
        scheduleBackgroundUpload()

        // Set up expiration handler
        task.expirationHandler = { [weak self] in
            SALogger.warn("Background upload task expired")
            self?.analytics?.uploader.shutdown()
        }

        // Perform the upload
        guard let analytics else {
            task.setTaskCompleted(success: false)
            return
        }

        let pendingCount = analytics.eventStore.pendingCountSync()
        if pendingCount == 0 {
            task.setTaskCompleted(success: true)
            return
        }

        // Flush and mark complete
        analytics.uploader.onUploadComplete = { result in
            switch result {
            case .success:
                SALogger.info("Background upload completed successfully")
                task.setTaskCompleted(success: true)
            case .failure:
                SALogger.warn("Background upload failed")
                task.setTaskCompleted(success: false)
            }
        }

        analytics.uploader.flush()
    }
}
#endif
