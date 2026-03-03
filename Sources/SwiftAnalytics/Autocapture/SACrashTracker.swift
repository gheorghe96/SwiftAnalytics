import Foundation

/// Captures unhandled exceptions and signals for crash reporting.
/// Events are written synchronously to SQLite to survive the crash.
final class SACrashTracker: SAEventPlugin {

    private static var isInstalled = false
    private static weak var sharedAnalytics: SwiftAnalytics?

    // Previous handlers (to chain)
    private static var previousExceptionHandler: NSExceptionHandler?
    private typealias NSExceptionHandler = @convention(c) (NSException) -> Void
    private static var previousSignalHandlers: [Int32: (@convention(c) (Int32) -> Void)?] = [:]

    init() {
        super.init(type: .utility)
    }

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        SACrashTracker.sharedAnalytics = analytics
        SACrashTracker.install()
    }

    override func teardown() {
        super.teardown()
    }

    // MARK: - Install

    private static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        // Install uncaught exception handler
        let previous = NSGetUncaughtExceptionHandler()
        previousExceptionHandler = previous

        NSSetUncaughtExceptionHandler { exception in
            SACrashTracker.handleException(exception)

            // Chain to previous handler
            SACrashTracker.previousExceptionHandler?(exception)
        }

        // Install signal handlers for common crash signals
        let signals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
        for sig in signals {
            let previous = signal(sig, SACrashTracker.handleSignal)
            previousSignalHandlers[sig] = previous
        }

        SALogger.info("Crash tracking installed")
    }

    // MARK: - Exception Handler

    private static func handleException(_ exception: NSException) {
        guard let analytics = sharedAnalytics else { return }

        let stackTrace = exception.callStackSymbols.joined(separator: "\n")
        let stackTraceHash = String(stackTrace.hashValue)

        let properties: SAProperties = [
            "exception_type": exception.name.rawValue,
            "reason": exception.reason ?? "Unknown",
            "stack_trace_hash": stackTraceHash,
            "stack_trace": String(stackTrace.prefix(4096)), // Limit size
        ]

        var event = SAEvent(eventType: SAConstants.EventType.applicationCrashed, eventProperties: properties)
        event.time = Int64(Date().timeIntervalSince1970 * 1000)

        // Write synchronously — we're about to crash
        analytics.eventStore.insertSync(event: event)

        SALogger.error("Crash captured: \(exception.name.rawValue) — \(exception.reason ?? "")")
    }

    // MARK: - Signal Handler

    private static let handleSignal: @convention(c) (Int32) -> Void = { sig in
        guard let analytics = sharedAnalytics else { return }

        let signalName: String
        switch sig {
        case SIGABRT: signalName = "SIGABRT"
        case SIGBUS:  signalName = "SIGBUS"
        case SIGFPE:  signalName = "SIGFPE"
        case SIGILL:  signalName = "SIGILL"
        case SIGSEGV: signalName = "SIGSEGV"
        case SIGTRAP: signalName = "SIGTRAP"
        default:      signalName = "SIGNAL_\(sig)"
        }

        let properties: SAProperties = [
            "exception_type": signalName,
            "reason": "Signal \(sig) received",
            "stack_trace_hash": "",
        ]

        var event = SAEvent(eventType: SAConstants.EventType.applicationCrashed, eventProperties: properties)
        event.time = Int64(Date().timeIntervalSince1970 * 1000)

        // Write synchronously — we're about to crash
        analytics.eventStore.insertSync(event: event)

        // Chain to previous handler
        if let previousHandler = previousSignalHandlers[sig], let handler = previousHandler {
            // Restore previous handler first to avoid recursion
            signal(sig, handler)
            raise(sig)
        } else {
            // Restore default and re-raise
            signal(sig, SIG_DFL)
            raise(sig)
        }
    }
}
