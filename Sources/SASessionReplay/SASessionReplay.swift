#if canImport(UIKit)
import UIKit
import Foundation
import SwiftAnalytics

/// Session Replay module — captures view hierarchy snapshots for replay.
/// Uploads replay data to MinIO (S3-compatible) via presigned URLs.
public final class SASessionReplayClient {

    /// Shared instance.
    public private(set) static var shared: SASessionReplayClient?

    private weak var analytics: SwiftAnalytics?
    private let configuration: SAReplayConfiguration
    private let recorder: SAReplayRecorder
    private let replayUploader: SAReplayUploader

    private var isRecording = false
    private var currentSessionId: Int64 = 0
    private var snapshotTimer: Timer?

    // MARK: - Init

    public init(analytics: SwiftAnalytics, configuration: SAReplayConfiguration) {
        self.analytics = analytics
        self.configuration = configuration
        self.recorder = SAReplayRecorder(configuration: configuration)
        self.replayUploader = SAReplayUploader(
            uploadURL: configuration.uploadURL,
            apiKey: configuration.apiKey
        )
    }

    @discardableResult
    public static func initialize(analytics: SwiftAnalytics,
                                  configuration: SAReplayConfiguration) -> SASessionReplayClient {
        let client = SASessionReplayClient(analytics: analytics, configuration: configuration)
        shared = client
        return client
    }

    // MARK: - Recording Control

    /// Start recording the current session.
    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        currentSessionId = analytics?.getSessionId() ?? Int64(Date().timeIntervalSince1970 * 1000)

        recorder.startSession(sessionId: currentSessionId)

        // Start periodic snapshot capture
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.snapshotTimer = Timer.scheduledTimer(
                withTimeInterval: self.configuration.snapshotInterval,
                repeats: true
            ) { [weak self] _ in
                self?.captureSnapshot()
            }
        }

        SALogger.info("Session replay started for session \(currentSessionId)")
    }

    /// Stop recording.
    public func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        snapshotTimer?.invalidate()
        snapshotTimer = nil

        // Finalize and upload
        let replayData = recorder.finalizeSession()
        if let replayData, !replayData.isEmpty {
            replayUploader.upload(
                sessionId: currentSessionId,
                data: replayData
            )
        }

        SALogger.info("Session replay stopped for session \(currentSessionId)")
    }

    // MARK: - Snapshot Capture

    private func captureSnapshot() {
        guard isRecording else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Capture the key window's view hierarchy
            guard let window = self.getKeyWindow() else { return }

            let snapshot = self.recorder.captureViewHierarchy(window: window)
            self.recorder.addSnapshot(snapshot)

            // Upload periodically if buffer is large enough
            if self.recorder.bufferSize > self.configuration.maxBufferSize {
                let chunk = self.recorder.flushBuffer()
                if let chunk {
                    self.replayUploader.uploadChunk(
                        sessionId: self.currentSessionId,
                        data: chunk
                    )
                }
            }
        }
    }

    private func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    // MARK: - Privacy Masking

    /// Add a view class to the privacy mask list (its content will be redacted in replays).
    public func mask(viewClass: AnyClass) {
        recorder.addMaskedClass(viewClass)
    }

    /// Mask a specific view instance.
    public func mask(view: UIView) {
        recorder.addMaskedView(view)
    }
}

// MARK: - Configuration

public struct SAReplayConfiguration {
    /// Server URL for uploading replay data (MinIO presigned URL endpoint).
    public let uploadURL: URL

    /// API key for authentication.
    public let apiKey: String

    /// Snapshot capture interval in seconds.
    public var snapshotInterval: TimeInterval = 1.0

    /// Maximum buffer size in bytes before force-flushing.
    public var maxBufferSize: Int = 1_048_576 // 1MB

    /// Whether to mask all text inputs by default.
    public var maskTextInputs: Bool = true

    /// Whether to mask images by default.
    public var maskImages: Bool = false

    /// Sampling rate (0.0–1.0). Only this fraction of sessions will be recorded.
    public var samplingRate: Double = 1.0

    public init(uploadURL: URL, apiKey: String) {
        self.uploadURL = uploadURL
        self.apiKey = apiKey
    }
}

// MARK: - Replay Recorder

/// Captures view hierarchy snapshots and encodes them as JSON diffs.
final class SAReplayRecorder {

    private let configuration: SAReplayConfiguration
    private var snapshots: [[String: Any]] = []
    private var maskedClasses: [AnyClass] = []
    private var maskedViews: [ObjectIdentifier] = []
    private var sessionId: Int64 = 0
    private let lock = NSLock()

    var bufferSize: Int {
        lock.lock()
        defer { lock.unlock() }
        // Approximate size
        return snapshots.count * 512
    }

    init(configuration: SAReplayConfiguration) {
        self.configuration = configuration

        // Default masked classes for privacy
        if configuration.maskTextInputs {
            maskedClasses.append(UITextField.self)
            maskedClasses.append(UITextView.self)
        }
    }

    func startSession(sessionId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        self.sessionId = sessionId
        snapshots.removeAll()
    }

    func captureViewHierarchy(window: UIWindow) -> [String: Any] {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let tree = serializeView(window)
        return [
            "timestamp": timestamp,
            "session_id": sessionId,
            "type": "snapshot",
            "tree": tree
        ]
    }

    func addSnapshot(_ snapshot: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        snapshots.append(snapshot)
    }

    func finalizeSession() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard !snapshots.isEmpty else { return nil }

        let payload: [String: Any] = [
            "session_id": sessionId,
            "snapshot_count": snapshots.count,
            "snapshots": snapshots
        ]

        let result = try? JSONSerialization.data(withJSONObject: payload)
        snapshots.removeAll()
        return result
    }

    func flushBuffer() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard !snapshots.isEmpty else { return nil }

        let payload: [String: Any] = [
            "session_id": sessionId,
            "snapshot_count": snapshots.count,
            "snapshots": snapshots,
            "type": "chunk"
        ]

        let result = try? JSONSerialization.data(withJSONObject: payload)
        snapshots.removeAll()
        return result
    }

    func addMaskedClass(_ cls: AnyClass) {
        lock.lock()
        defer { lock.unlock() }
        maskedClasses.append(cls)
    }

    func addMaskedView(_ view: UIView) {
        lock.lock()
        defer { lock.unlock() }
        maskedViews.append(ObjectIdentifier(view))
    }

    // MARK: - View Serialization

    private func serializeView(_ view: UIView) -> [String: Any] {
        let isMasked = shouldMask(view)

        var node: [String: Any] = [
            "class": String(describing: type(of: view)),
            "frame": [
                "x": view.frame.origin.x,
                "y": view.frame.origin.y,
                "w": view.frame.size.width,
                "h": view.frame.size.height
            ],
            "hidden": view.isHidden,
            "alpha": view.alpha
        ]

        if isMasked {
            node["masked"] = true
        } else {
            // Capture text content (non-masked)
            if let label = view as? UILabel {
                node["text"] = label.text ?? ""
            } else if let button = view as? UIButton {
                node["text"] = button.titleLabel?.text ?? ""
            } else if let imageView = view as? UIImageView {
                node["has_image"] = imageView.image != nil
                if configuration.maskImages {
                    node["masked"] = true
                }
            }
        }

        // Recursively serialize subviews
        if !view.subviews.isEmpty {
            node["children"] = view.subviews.map { serializeView($0) }
        }

        return node
    }

    private func shouldMask(_ view: UIView) -> Bool {
        // Check if this specific view is masked
        if maskedViews.contains(ObjectIdentifier(view)) {
            return true
        }

        // Check if this view's class is masked
        for cls in maskedClasses {
            if view.isKind(of: cls) {
                return true
            }
        }

        return false
    }
}

// MARK: - Replay Uploader

/// Uploads replay data to MinIO-compatible storage via presigned URLs.
final class SAReplayUploader {

    private let uploadURL: URL
    private let apiKey: String
    private let session: URLSession

    init(uploadURL: URL, apiKey: String) {
        self.uploadURL = uploadURL
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }

    /// Upload complete session replay data.
    func upload(sessionId: Int64, data: Data) {
        let url = uploadURL.appendingPathComponent("/replay/\(sessionId)")
        performUpload(url: url, data: data)
    }

    /// Upload a chunk of replay data (for long sessions).
    func uploadChunk(sessionId: Int64, data: Data) {
        let chunkId = UUID().uuidString
        let url = uploadURL.appendingPathComponent("/replay/\(sessionId)/\(chunkId)")
        performUpload(url: url, data: data)
    }

    private func performUpload(url: URL, data: Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let task = session.dataTask(with: request) { _, response, error in
            if let error {
                SALogger.error("Replay upload failed: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                SALogger.debug("Replay chunk uploaded successfully")
            }
        }
        task.resume()
    }
}
#else
// Non-UIKit platforms — no session replay
import Foundation
public enum SASessionReplayPlaceholder {
    public static let version = "3.0.0"
}
#endif
