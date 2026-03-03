import Foundation
import SwiftAnalytics

/// A/B Experimentation and Feature Flag module.
/// Provides remote feature flags, local evaluation, and exposure tracking.
public final class SAExperimentClient {

    /// Shared experiment client instance.
    public private(set) static var shared: SAExperimentClient?

    private let serverURL: URL
    private let apiKey: String
    private let flagStore: SAFlagStore
    private let session: URLSession
    private weak var analytics: SwiftAnalytics?

    private var fetchTask: URLSessionDataTask?

    // MARK: - Init

    /// Initialize with an analytics instance and experiment server URL.
    public init(analytics: SwiftAnalytics, serverURL: URL, apiKey: String) {
        self.analytics = analytics
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.flagStore = SAFlagStore(apiKey: apiKey)
        self.session = URLSession(configuration: .default)
    }

    /// Initialize as shared singleton.
    @discardableResult
    public static func initialize(analytics: SwiftAnalytics, serverURL: URL, apiKey: String) -> SAExperimentClient {
        let client = SAExperimentClient(analytics: analytics, serverURL: serverURL, apiKey: apiKey)
        shared = client
        return client
    }

    // MARK: - Fetch Flags

    /// Fetch feature flags from server for the current user.
    public func fetch(completion: ((Result<Void, Error>) -> Void)? = nil) {
        let userId = analytics?.getUserId()
        let deviceId = analytics?.getDeviceId() ?? ""

        var body: [String: Any] = ["device_id": deviceId]
        if let userId { body["user_id"] = userId }

        let url = serverURL.appendingPathComponent("/v1/flags")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        fetchTask?.cancel()
        fetchTask = session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion?(.failure(error))
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                completion?(.failure(SAError.serializationError("Invalid flag response")))
                return
            }

            self?.flagStore.updateFlags(from: json)
            completion?(.success(()))
        }
        fetchTask?.resume()
    }

    /// Fetch flags using async/await.
    public func fetchAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            fetch { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Variant Access

    /// Get the variant for a flag. Returns the variant object or nil if not found.
    public func variant(_ flagKey: String) -> SAVariant {
        let variant = flagStore.variant(forKey: flagKey)

        // Track exposure
        if let variant, variant.key != nil {
            trackExposure(flagKey: flagKey, variant: variant)
        }

        return variant ?? SAVariant.off
    }

    /// Get the variant value as a string. Returns the fallback if not found.
    public func variant(_ flagKey: String, fallback: String) -> String {
        let v = variant(flagKey)
        return v.value ?? fallback
    }

    /// Check if a feature flag is on (variant is not "off" and not nil).
    public func isOn(_ flagKey: String) -> Bool {
        let v = variant(flagKey)
        return v.isOn
    }

    // MARK: - Exposure Tracking

    private func trackExposure(flagKey: String, variant: SAVariant) {
        analytics?.track("$exposure", eventProperties: [
            "flag_key": flagKey,
            "variant": variant.key ?? "off",
            "experiment_key": flagKey
        ])
    }

    // MARK: - Clear

    /// Clear all cached flags.
    public func clear() {
        flagStore.clear()
    }
}

// MARK: - Variant Model

/// Represents a variant assignment for a feature flag or experiment.
public struct SAVariant {
    /// The variant key (e.g., "control", "treatment", "on", "off").
    public let key: String?

    /// The variant value (payload). Can be a string, JSON, etc.
    public let value: String?

    /// Optional payload object (parsed JSON).
    public let payload: Any?

    /// Whether this variant is considered "on" (not off/nil).
    public var isOn: Bool {
        key != nil && key != "off"
    }

    public init(key: String? = nil, value: String? = nil, payload: Any? = nil) {
        self.key = key
        self.value = value
        self.payload = payload
    }

    /// Default "off" variant.
    public static let off = SAVariant(key: "off", value: nil, payload: nil)

    /// Parse from server JSON.
    static func fromJSON(_ json: [String: Any]) -> SAVariant {
        SAVariant(
            key: json["key"] as? String,
            value: json["value"] as? String,
            payload: json["payload"]
        )
    }
}

// MARK: - Flag Store

/// Persists feature flag assignments in UserDefaults.
final class SAFlagStore {

    private let defaults: UserDefaults
    private var flags: [String: SAVariant] = [:]
    private let lock = NSLock()

    init(apiKey: String) {
        self.defaults = UserDefaults(suiteName: "com.swiftanalytics.experiment.\(apiKey)") ?? .standard
        loadFromDisk()
    }

    func variant(forKey key: String) -> SAVariant? {
        lock.lock()
        defer { lock.unlock() }
        return flags[key]
    }

    func updateFlags(from json: [[String: Any]]) {
        lock.lock()
        defer { lock.unlock() }

        flags.removeAll()
        for flagJSON in json {
            guard let key = flagJSON["flag_key"] as? String ?? flagJSON["key"] as? String else { continue }
            flags[key] = SAVariant.fromJSON(flagJSON)
        }

        saveToDisk()
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        flags.removeAll()
        defaults.removeObject(forKey: "sa_experiment_flags")
    }

    // MARK: - Persistence

    private func saveToDisk() {
        var serialized = [[String: Any]]()
        for (key, variant) in flags {
            var entry: [String: Any] = ["flag_key": key]
            if let k = variant.key { entry["key"] = k }
            if let v = variant.value { entry["value"] = v }
            serialized.append(entry)
        }
        if let data = try? JSONSerialization.data(withJSONObject: serialized) {
            defaults.set(data, forKey: "sa_experiment_flags")
        }
    }

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: "sa_experiment_flags"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        for flagJSON in json {
            guard let key = flagJSON["flag_key"] as? String else { continue }
            flags[key] = SAVariant.fromJSON(flagJSON)
        }
    }
}
