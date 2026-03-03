import Foundation

/// HTTP batch uploader that reads from the SQLite event store and sends to the ingestion API.
/// Handles batching, gzip compression, retry with exponential backoff, and response code handling.
final class SAUploader {

    private let configuration: SAConfiguration
    private let eventStore: SAEventStore
    private let session: URLSession
    private let uploadQueue = DispatchQueue(label: "com.swiftanalytics.uploader", qos: .utility)

    private var flushTimer: DispatchSourceTimer?
    private var isUploading = false
    private var isShutDown = false

    private let backoffSchedule: [TimeInterval] = [1, 2, 4, 8, 16, 32]

    /// Callback for upload completion (for track-with-callback feature).
    var onUploadComplete: ((Result<Int, Error>) -> Void)?

    init(configuration: SAConfiguration, eventStore: SAEventStore) {
        self.configuration = configuration
        self.eventStore = eventStore

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        sessionConfig.waitsForConnectivity = true
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Lifecycle

    func start() {
        startFlushTimer()
    }

    func shutdown() {
        isShutDown = true
        stopFlushTimer()
        // Final flush attempt
        flush()
    }

    // MARK: - Flush Timer

    private func startFlushTimer() {
        stopFlushTimer()

        let interval = Double(configuration.flushIntervalMillis) / 1000.0
        let timer = DispatchSource.makeTimerSource(queue: uploadQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.flush()
        }
        timer.resume()
        flushTimer = timer
    }

    private func stopFlushTimer() {
        flushTimer?.cancel()
        flushTimer = nil
    }

    // MARK: - Flush

    func flush() {
        uploadQueue.async { [weak self] in
            self?.performFlush()
        }
    }

    /// Synchronous flush for app backgrounding.
    func flushSync() {
        uploadQueue.sync {
            performFlush()
        }
    }

    private func performFlush() {
        guard !isUploading else {
            SALogger.debug("Upload already in progress, skipping")
            return
        }

        isUploading = true
        defer { isUploading = false }

        let events = eventStore.fetchPendingSync(limit: configuration.flushQueueSize)
        guard !events.isEmpty else {
            SALogger.verbose("No pending events to flush")
            return
        }

        SALogger.info("Flushing \(events.count) events")

        // Build the batch payload
        let payload = buildPayload(events: events.map(\.event))

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let compressed = gzipCompress(jsonData) else {
            SALogger.error("Failed to serialize or compress event batch")
            return
        }

        // Check batch size limit
        if compressed.count > configuration.maxBatchSizeBytes && events.count > 1 {
            // Split batch in half and retry
            let mid = events.count / 2
            let firstHalf = Array(events.prefix(mid))
            let secondHalf = Array(events.suffix(from: mid))

            SALogger.info("Batch too large (\(compressed.count) bytes), splitting")

            uploadBatch(events: firstHalf, retryCount: 0)
            uploadBatch(events: secondHalf, retryCount: 0)
            return
        }

        uploadBatch(events: events, retryCount: 0)
    }

    // MARK: - Upload

    private func uploadBatch(events: [StoredEvent], retryCount: Int) {
        let payload = buildPayload(events: events.map(\.event))

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            SALogger.error("Failed to serialize batch payload")
            return
        }

        let compressed = gzipCompress(jsonData) ?? jsonData
        let useGzip = compressed.count < jsonData.count

        let url = configuration.serverURL.appendingPathComponent(SAConstants.HTTP.defaultEndpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SAConstants.HTTP.contentTypeJSON, forHTTPHeaderField: "Content-Type")
        if useGzip {
            request.setValue(SAConstants.HTTP.contentEncodingGzip, forHTTPHeaderField: "Content-Encoding")
        }
        request.httpBody = useGzip ? compressed : jsonData

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                SALogger.error("Upload failed: \(error.localizedDescription)")
                self.handleRetry(events: events, retryCount: retryCount)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.handleRetry(events: events, retryCount: retryCount)
                return
            }

            self.handleResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields,
                events: events,
                retryCount: retryCount
            )
        }
        task.resume()
    }

    // MARK: - Response Handling

    private func handleResponse(statusCode: Int, headers: [AnyHashable: Any],
                                events: [StoredEvent], retryCount: Int) {
        let rowIds = events.map(\.rowId)

        switch statusCode {
        case 200:
            // Success — delete from queue
            eventStore.delete(ids: rowIds)
            onUploadComplete?(.success(events.count))
            SALogger.info("Successfully uploaded \(events.count) events")

        case 400:
            // Bad request — malformed data, discard (retry won't help)
            eventStore.delete(ids: rowIds)
            SALogger.error("Server returned 400 — batch discarded (malformed)")

        case 413:
            // Payload too large — split and retry
            if events.count > 1 {
                let mid = events.count / 2
                uploadBatch(events: Array(events.prefix(mid)), retryCount: 0)
                uploadBatch(events: Array(events.suffix(from: mid)), retryCount: 0)
            } else {
                // Single event too large — discard
                eventStore.delete(ids: rowIds)
                SALogger.error("Single event too large — discarded")
            }

        case 429:
            // Rate limited — respect Retry-After
            let retryAfter = headers["Retry-After"] as? String
            let delay = TimeInterval(retryAfter ?? "") ?? backoffDelay(for: retryCount)
            scheduleRetry(events: events, retryCount: retryCount, delay: delay)

        case 500, 502, 503:
            // Server error — retry with backoff
            handleRetry(events: events, retryCount: retryCount)

        default:
            SALogger.warn("Unexpected status code: \(statusCode)")
            handleRetry(events: events, retryCount: retryCount)
        }
    }

    // MARK: - Retry

    private func handleRetry(events: [StoredEvent], retryCount: Int) {
        guard retryCount < configuration.uploadRetryCount else {
            SALogger.error("Max retries reached for batch of \(events.count) events")
            // Mark events as failed (they'll be picked up on next flush)
            for event in events {
                eventStore.updateStatus(id: event.rowId, status: .failed)
            }
            onUploadComplete?(.failure(SAError.uploadError("Max retries exceeded")))
            return
        }

        let delay = backoffDelay(for: retryCount)
        scheduleRetry(events: events, retryCount: retryCount, delay: delay)
    }

    private func scheduleRetry(events: [StoredEvent], retryCount: Int, delay: TimeInterval) {
        SALogger.info("Retrying upload in \(delay)s (attempt \(retryCount + 1))")
        uploadQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.uploadBatch(events: events, retryCount: retryCount + 1)
        }
    }

    private func backoffDelay(for retry: Int) -> TimeInterval {
        if retry < backoffSchedule.count {
            return backoffSchedule[retry]
        }
        return backoffSchedule.last ?? 32
    }

    // MARK: - Payload Building

    private func buildPayload(events: [SAEvent]) -> [String: Any] {
        let eventJSONs = events.map { event -> [String: Any] in
            var json = event.toJSON()
            json["client_upload_time"] = ISO8601DateFormatter().string(from: Date())
            return json
        }

        return [
            "api_key": configuration.apiKey,
            "events": eventJSONs,
            "options": ["min_id_length": configuration.minIdLength]
        ]
    }

    // MARK: - Gzip Compression

    private func gzipCompress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        // Use built-in compression framework (available iOS 13+)
        return try? (data as NSData).compressed(using: .zlib) as Data
    }
}
