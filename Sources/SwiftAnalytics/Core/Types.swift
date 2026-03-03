import Foundation

// MARK: - Type Aliases
public typealias SAProperties = [String: Any]
public typealias SAUploadCallback = (Result<Void, Error>) -> Void

// MARK: - Autocapture Options
public struct SAAutocaptureOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let appLifecycle     = SAAutocaptureOptions(rawValue: 1 << 0)
    public static let sessions         = SAAutocaptureOptions(rawValue: 1 << 1)
    public static let screenViews      = SAAutocaptureOptions(rawValue: 1 << 2)
    public static let deepLinks        = SAAutocaptureOptions(rawValue: 1 << 3)
    public static let pushNotifications = SAAutocaptureOptions(rawValue: 1 << 4)
    public static let networkType      = SAAutocaptureOptions(rawValue: 1 << 5)
    public static let crashes          = SAAutocaptureOptions(rawValue: 1 << 6)

    public static let all: SAAutocaptureOptions = [
        .appLifecycle, .sessions, .screenViews, .deepLinks,
        .pushNotifications, .networkType, .crashes
    ]

    public static let none: SAAutocaptureOptions = []
}

// MARK: - Location Tracking Mode
public enum SALocationTracking: Sendable {
    case disabled
    case whenAuthorized
}

// MARK: - Log Level
public enum SALogLevel: Int, Comparable, Sendable {
    case off = 0
    case error = 1
    case warn = 2
    case info = 3
    case debug = 4
    case verbose = 5

    public static func < (lhs: SALogLevel, rhs: SALogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Upload Status
public enum SAUploadStatus: String {
    case pending = "pending"
    case uploading = "uploading"
    case failed = "failed"
}

// MARK: - Consent State
public enum SAConsentState: String, Codable, Sendable {
    case unknown = "unknown"
    case optedIn = "opted_in"
    case optedOut = "opted_out"
}

// MARK: - SDK Errors
public enum SAError: Error, LocalizedError {
    case notInitialized
    case invalidAPIKey
    case invalidEvent(String)
    case storageError(String)
    case uploadError(String)
    case networkError(Error)
    case serializationError(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized: return "SwiftAnalytics SDK not initialized"
        case .invalidAPIKey: return "Invalid API key"
        case .invalidEvent(let msg): return "Invalid event: \(msg)"
        case .storageError(let msg): return "Storage error: \(msg)"
        case .uploadError(let msg): return "Upload error: \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .serializationError(let msg): return "Serialization error: \(msg)"
        }
    }
}

// MARK: - Internal Logger
final class SALogger {
    static var logLevel: SALogLevel = .warn

    static func error(_ message: @autoclosure () -> String) {
        log(.error, message())
    }

    static func warn(_ message: @autoclosure () -> String) {
        log(.warn, message())
    }

    static func info(_ message: @autoclosure () -> String) {
        log(.info, message())
    }

    static func debug(_ message: @autoclosure () -> String) {
        log(.debug, message())
    }

    static func verbose(_ message: @autoclosure () -> String) {
        log(.verbose, message())
    }

    private static func log(_ level: SALogLevel, _ message: String) {
        guard level <= logLevel else { return }
        let prefix: String
        switch level {
        case .off: return
        case .error:   prefix = "[SA:ERROR]"
        case .warn:    prefix = "[SA:WARN]"
        case .info:    prefix = "[SA:INFO]"
        case .debug:   prefix = "[SA:DEBUG]"
        case .verbose: prefix = "[SA:VERBOSE]"
        }
        print("\(prefix) \(message)")
    }
}
