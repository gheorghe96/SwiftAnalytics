import Foundation

/// WebSocket client for receiving realtime analytics metrics.
/// Uses URLSessionWebSocketTask (built into Foundation — no external library).
public final class SARealtimeClient {

    private let serverURL: URL
    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var isConnected = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 10
    private let reconnectBaseDelay: TimeInterval = 1.0

    /// Called when realtime metrics are received.
    public var onMetricsUpdate: ((SARealtimeMetrics) -> Void)?

    /// Called when an individual event is received on the live stream.
    public var onEventStream: (([String: Any]) -> Void)?

    /// Called when connection state changes.
    public var onConnectionStateChanged: ((Bool) -> Void)?

    public init(serverURL: URL, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }

    public convenience init(serverURL: String, apiKey: String) {
        self.init(serverURL: URL(string: serverURL)!, apiKey: apiKey)
    }

    // MARK: - Connection

    public func connect() {
        guard !isConnected else { return }

        // Build WebSocket URL with API key
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        guard let wsURL = components?.url else {
            SALogger.error("Invalid realtime WebSocket URL")
            return
        }

        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        isConnected = true
        reconnectAttempt = 0
        onConnectionStateChanged?(true)

        SALogger.info("Realtime WebSocket connected to \(wsURL)")

        receiveMessage()
    }

    public func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        onConnectionStateChanged?(false)
        SALogger.info("Realtime WebSocket disconnected")
    }

    // MARK: - Receive

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self, self.isConnected else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                SALogger.error("WebSocket receive error: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .string(let text):
            guard let textData = text.data(using: .utf8) else { return }
            data = textData
        case .data(let binaryData):
            data = binaryData
        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let messageType = json["type"] as? String

        switch messageType {
        case "realtime_metrics":
            if let metricsData = json["data"] as? [String: Any] {
                let metrics = SARealtimeMetrics(json: metricsData)
                DispatchQueue.main.async {
                    self.onMetricsUpdate?(metrics)
                }
            }

        case "event":
            if let eventData = json["data"] as? [String: Any] {
                DispatchQueue.main.async {
                    self.onEventStream?(eventData)
                }
            }

        default:
            SALogger.verbose("Unknown realtime message type: \(messageType ?? "nil")")
        }
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        isConnected = false
        onConnectionStateChanged?(false)

        guard reconnectAttempt < maxReconnectAttempts else {
            SALogger.error("Max reconnect attempts reached")
            return
        }

        reconnectAttempt += 1
        let delay = reconnectBaseDelay * pow(2.0, Double(reconnectAttempt - 1))
        let jitter = Double.random(in: 0...1)

        SALogger.info("Reconnecting in \(delay + jitter)s (attempt \(reconnectAttempt))")

        DispatchQueue.global().asyncAfter(deadline: .now() + delay + jitter) { [weak self] in
            self?.connect()
        }
    }

    // MARK: - Send

    public func send(message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        webSocketTask?.send(.data(data)) { error in
            if let error {
                SALogger.error("WebSocket send error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Realtime Metrics Model

public struct SARealtimeMetrics {
    public let activeUsersNow: Int
    public let activeUsers30m: Int
    public let activeUsers1h: Int
    public let eventsPerMinute: Int
    public let newUsersToday: Int
    public let activeSessions: Int
    public let revenueLastHour: Double
    public let crashesPerMinute: Int
    public let topEvents: [SATopItem]
    public let usersByCountry: [SACountryItem]
    public let topCities: [SACityItem]

    init(json: [String: Any]) {
        self.activeUsersNow = json["active_users_now"] as? Int ?? 0
        self.activeUsers30m = json["active_users_30m"] as? Int ?? 0
        self.activeUsers1h = json["active_users_1h"] as? Int ?? 0
        self.eventsPerMinute = json["events_per_minute"] as? Int ?? 0
        self.newUsersToday = json["new_users_today"] as? Int ?? 0
        self.activeSessions = json["active_sessions"] as? Int ?? 0
        self.revenueLastHour = json["revenue_last_hour"] as? Double ?? 0
        self.crashesPerMinute = json["crashes_per_minute"] as? Int ?? 0

        self.topEvents = (json["top_events"] as? [[String: Any]] ?? []).map {
            SATopItem(eventType: $0["event_type"] as? String ?? "", count: $0["count"] as? Int ?? 0)
        }
        self.usersByCountry = (json["users_by_country"] as? [[String: Any]] ?? []).map {
            SACountryItem(
                country: $0["country"] as? String ?? "",
                code: $0["code"] as? String ?? "",
                count: $0["count"] as? Int ?? 0
            )
        }
        self.topCities = (json["top_cities"] as? [[String: Any]] ?? []).map {
            SACityItem(
                city: $0["city"] as? String ?? "",
                code: $0["code"] as? String ?? "",
                count: $0["count"] as? Int ?? 0
            )
        }
    }
}

public struct SATopItem {
    public let eventType: String
    public let count: Int
}

public struct SACountryItem {
    public let country: String
    public let code: String
    public let count: Int
}

public struct SACityItem {
    public let city: String
    public let code: String
    public let count: Int
}
