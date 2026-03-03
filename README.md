# SwiftAnalytics

Self-hosted iOS analytics SDK with full Amplitude feature parity. Zero external dependencies — only Apple system frameworks.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add SwiftAnalytics to your project via Xcode:

1. **File > Add Package Dependencies...**
2. Enter the repository URL
3. Select the products you need:
   - **SwiftAnalytics** — Core SDK (required)
   - **SASessionReplay** — Session replay recording (optional)
   - **SAExperiment** — A/B testing and feature flags (optional)

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/SwiftAnalytics.git", from: "3.0.0")
]
```

Then add the target dependency:

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftAnalytics"]
)
```

## Quick Start

### 1. Initialize the SDK

Initialize SwiftAnalytics as early as possible — typically in `AppDelegate` or `@main App`.

**UIKit (AppDelegate):**

```swift
import SwiftAnalytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let config = SAConfiguration(
            apiKey: "YOUR_API_KEY",
            serverURL: "https://your-analytics-server.com/2/httpapi"
        )
        SwiftAnalytics.initialize(configuration: config)

        return true
    }
}
```

**SwiftUI:**

```swift
import SwiftUI
import SwiftAnalytics

@main
struct YourApp: App {
    init() {
        let config = SAConfiguration(
            apiKey: "YOUR_API_KEY",
            serverURL: "https://your-analytics-server.com/2/httpapi"
        )
        SwiftAnalytics.initialize(configuration: config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Track Events

```swift
// Simple event
SwiftAnalytics.shared?.track("Button Tapped")

// Event with properties
SwiftAnalytics.shared?.track("Product Viewed", eventProperties: [
    "product_id": "SKU-123",
    "price": 29.99,
    "category": "Electronics"
])

// Using the event builder
let event = SAEventBuilder("Purchase Completed")
    .set("item_count", value: 3)
    .set("total", value: 89.97)
    .build()
SwiftAnalytics.shared?.track(event)
```

### 3. Identify Users

```swift
// Set user ID after login
SwiftAnalytics.shared?.setUserId("user-42")

// Set user properties
let identify = SAIdentify()
    .set("plan", value: "premium")
    .set("email", value: "user@example.com")
    .setOnce("signup_date", value: "2025-01-15")
    .add("login_count", value: 1)

SwiftAnalytics.shared?.identify(identify: identify)

// Or combine both:
SwiftAnalytics.shared?.identify(userId: "user-42", identify: identify)
```

### 4. Track Revenue

```swift
let revenue = SARevenue()
revenue.productId = "premium_monthly"
revenue.price = 9.99
revenue.quantity = 1
revenue.revenueType = "subscription"
revenue.currency = "USD"

SwiftAnalytics.shared?.logRevenue(revenue)
```

StoreKit 2 transactions are captured automatically — no extra code needed.

## Configuration

All configuration options with their defaults:

```swift
let config = SAConfiguration(
    apiKey: "YOUR_API_KEY",
    serverURL: "https://your-server.com/2/httpapi",

    // Upload settings
    flushIntervalMillis: 30_000,       // Flush every 30 seconds
    flushQueueSize: 30,                // Flush when queue reaches 30 events
    maxQueueDepth: 1000,               // Max events stored locally
    maxBatchSizeBytes: 10_485_760,     // 10 MB max batch size
    uploadRetryCount: 6,               // Retry failed uploads 6 times
    flushOnBackground: true,           // Flush when app enters background
    uploadOnWifiOnly: false,           // Upload on any connection

    // Session settings
    minTimeBetweenSessionsMillis: 300_000,  // 5-minute session gap
    trackingSessionEvents: true,             // Auto-track session start/end

    // Autocapture
    autocapture: .all,                 // Capture everything (see below)
    locationTracking: .disabled,       // GPS tracking (see below)

    // Privacy
    enableCoppaControl: false,
    optOut: false,                     // Start opted-in
    trackingOptions: SATrackingOptions(),

    // Logging
    logLevel: .warn,                   // .off, .error, .warn, .info, .debug, .verbose

    // Optional modules
    enableRealtime: false,
    realtimeURL: nil,
    enableSessionReplay: false,
    defaultPluginsEnabled: true
)
```

### Autocapture Options

Control which events are captured automatically:

```swift
// Capture everything
config.autocapture = .all

// Disable all autocapture
config.autocapture = .none

// Pick specific options
config.autocapture = [.appLifecycle, .sessions, .screenViews]
```

| Option | Description |
|--------|-------------|
| `.appLifecycle` | App install, update, open, background |
| `.sessions` | Session start and end events |
| `.screenViews` | UIViewController screen transitions |
| `.deepLinks` | Deep link / universal link opens |
| `.pushNotifications` | Push notification received and opened |
| `.networkType` | Carrier and network type (WiFi/cellular) |
| `.crashes` | Uncaught exceptions and fatal signals |

## User Identity

```swift
// Set user ID (after login)
SwiftAnalytics.shared?.setUserId("user-42")

// Clear user ID (after logout)
SwiftAnalytics.shared?.setUserId(nil)

// Reset everything (new device ID, clear user ID, new session)
SwiftAnalytics.shared?.reset()

// Get current IDs
let userId = SwiftAnalytics.shared?.getUserId()
let deviceId = SwiftAnalytics.shared?.getDeviceId()
let sessionId = SwiftAnalytics.shared?.getSessionId()

// Override device ID (for cross-platform identity)
SwiftAnalytics.shared?.setDeviceId("custom-device-id")
```

## Identify Operations

All 10 Amplitude-compatible identify operations are supported:

```swift
let identify = SAIdentify()
    .set("name", value: "John")              // Unconditional write
    .setOnce("first_seen", value: "today")   // Write only if never set
    .add("login_count", value: 1)            // Increment numeric
    .append("tags", value: "vip")            // Add to end of array
    .prepend("tags", value: "new")           // Add to start of array
    .postInsert("items", value: "x")         // Add to end (no duplicates)
    .preInsert("items", value: "y")          // Add to start (no duplicates)
    .remove("tags", value: "old")            // Remove from array
    .unset("temp_flag")                      // Delete property

SwiftAnalytics.shared?.identify(identify: identify)

// Clear all user properties
let clearIdentify = SAIdentify()
clearIdentify.clearAll()
SwiftAnalytics.shared?.identify(identify: clearIdentify)
```

## Group Analytics

```swift
// Assign user to a group
SwiftAnalytics.shared?.setGroup(groupType: "company", groupName: "Acme Inc")

// Set properties on a group
let groupIdentify = SAIdentify()
    .set("plan", value: "enterprise")
    .set("employee_count", value: 500)

SwiftAnalytics.shared?.groupIdentify(
    groupType: "company",
    groupName: "Acme Inc",
    identify: groupIdentify
)
```

## Deep Links

Track deep links from `AppDelegate` or `SceneDelegate`. UTM parameters are automatically persisted across sessions.

```swift
// AppDelegate
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    SwiftAnalytics.shared?.trackDeepLink(
        url: url,
        sourceApplication: options[.sourceApplication] as? String
    )
    return true
}

// SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    SwiftAnalytics.shared?.trackDeepLink(url: url)
}
```

## SwiftUI Screen Tracking

Use the `.saTrackScreen()` modifier for SwiftUI views:

```swift
import SwiftAnalytics

struct ProductDetailView: View {
    var body: some View {
        VStack {
            Text("Product Details")
        }
        .saTrackScreen("Product Detail")
    }
}
```

UIKit screen views are tracked automatically via `viewDidAppear` swizzling when `.screenViews` autocapture is enabled.

## Location Tracking

GPS coordinates are captured only when the host app already has location permission — the SDK never requests permission itself.

```swift
let config = SAConfiguration(
    apiKey: "YOUR_API_KEY",
    serverURL: "https://your-server.com/2/httpapi",
    locationTracking: .whenAuthorized
)
```

Also enable lat/lng in tracking options:

```swift
var trackingOptions = SATrackingOptions()
trackingOptions.trackLatLng = true
config.trackingOptions = trackingOptions
```

## IDFA / App Tracking Transparency

Add the opt-in IDFA plugin after initialization:

```swift
let analytics = SwiftAnalytics.initialize(configuration: config)

// Add IDFA plugin (requires ATT permission)
let idfaPlugin = SAIDFAPlugin()
analytics.add(plugin: idfaPlugin)

// Request ATT authorization (iOS 14+)
idfaPlugin.requestAuthorization()
```

Also enable IDFA in tracking options:

```swift
var trackingOptions = SATrackingOptions()
trackingOptions.trackIDFA = true
config.trackingOptions = trackingOptions
```

Don't forget to add `NSUserTrackingUsageDescription` to your `Info.plist`.

## Privacy & Consent

### Opt Out / Opt In

```swift
// Opt user out of all tracking
SwiftAnalytics.shared?.optOut()

// Check status
if SwiftAnalytics.shared?.isOptedOut == true {
    // No events are being tracked
}

// Opt back in
SwiftAnalytics.shared?.optIn()
```

### COPPA Compliance

```swift
let config = SAConfiguration(
    apiKey: "YOUR_API_KEY",
    serverURL: "https://your-server.com/2/httpapi",
    enableCoppaControl: true,
    trackingOptions: .forCOPPA()
)
```

### Tracking Options

Disable individual device/geo properties:

```swift
var options = SATrackingOptions()
options.trackIPAddress = false
options.trackCity = false
options.trackCarrier = false
config.trackingOptions = options
```

## Realtime Analytics

Connect to a WebSocket server for live metrics:

```swift
let config = SAConfiguration(
    apiKey: "YOUR_API_KEY",
    serverURL: "https://your-server.com/2/httpapi",
    enableRealtime: true,
    realtimeURL: URL(string: "wss://your-server.com/ws/realtime")
)

let analytics = SwiftAnalytics.initialize(configuration: config)

// Subscribe to live metrics
analytics.realtimeClient?.onMetrics = { metrics in
    print("Active users: \(metrics.activeUsers)")
    print("Events/min: \(metrics.eventsPerMinute)")
}
```

## Plugin Architecture

Create custom plugins to intercept, enrich, or redirect events:

```swift
// Enrichment plugin — adds properties to every event
class MyEnrichmentPlugin: SAEventPlugin {
    init() {
        super.init(type: .enrichment)
    }

    override func execute(event: SAEvent) -> SAEvent? {
        var modified = event
        if modified.eventProperties == nil {
            modified.eventProperties = [:]
        }
        modified.eventProperties?["app_variant"] = "beta"
        return modified
    }
}

// Before plugin — can filter or block events
class EventFilterPlugin: SAEventPlugin {
    init() {
        super.init(type: .before)
    }

    override func execute(event: SAEvent) -> SAEvent? {
        // Drop debug events in production
        if event.eventType.hasPrefix("debug_") {
            return nil  // Returning nil drops the event
        }
        return event
    }
}

// Add plugins
let analytics = SwiftAnalytics.initialize(configuration: config)
analytics.add(plugin: MyEnrichmentPlugin())
analytics.add(plugin: EventFilterPlugin())
```

## A/B Experiments (Optional Module)

Add the `SAExperiment` product to your dependencies:

```swift
import SAExperiment

// Initialize experiment client
let experimentConfig = SAExperimentConfig(
    serverURL: "https://your-server.com/experiments",
    apiKey: "YOUR_API_KEY"
)
let experiments = SAExperimentClient(config: experimentConfig, analytics: analytics)

// Fetch flag values
experiments.fetch { result in
    switch result {
    case .success:
        let variant = experiments.variant("onboarding-flow")
        if variant.isOn {
            // Show new onboarding
        }
    case .failure(let error):
        print("Failed to fetch experiments: \(error)")
    }
}
```

## Session Replay (Optional Module)

Add the `SASessionReplay` product to your dependencies:

```swift
import SASessionReplay

// Start recording
let replayConfig = SASessionReplayConfig(
    serverURL: "https://your-minio-server.com",
    apiKey: "YOUR_API_KEY"
)
let replay = SASessionReplayClient(config: replayConfig, analytics: analytics)
replay.start()

// Privacy masking
replay.maskView(sensitiveTextField)

// Stop recording
replay.stop()
```

## Background Uploads

The SDK automatically schedules background uploads using `BGProcessingTask` when `flushOnBackground` is enabled (default). To register the background task identifier, add this to your `Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.swiftanalytics.upload</string>
</array>
```

Then register the task handler in your AppDelegate:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let analytics = SwiftAnalytics.initialize(configuration: config)

    // Register background task handler
    analytics.backgroundTaskManager?.registerBackgroundTask()

    return true
}
```

## Flush & Shutdown

```swift
// Manually flush pending events
SwiftAnalytics.shared?.flush()

// Gracefully shut down (flushes and releases resources)
SwiftAnalytics.shared?.shutdown()
```

## Event Schema

Every event automatically includes:

| Field | Description |
|-------|-------------|
| `event_type` | Event name |
| `user_id` | User identifier (set via `setUserId`) |
| `device_id` | Auto-generated device identifier |
| `session_id` | Current session timestamp |
| `event_id` | Auto-incrementing sequence number |
| `time` | Event timestamp (ms) |
| `insert_id` | UUID for server-side deduplication |
| `platform` | `iOS` |
| `os_name` / `os_version` | Operating system info |
| `device_model` / `device_family` | Hardware info |
| `app_version` / `app_build` | Bundle version |
| `carrier` | Mobile carrier name |
| `network_type` | `wifi`, `cellular`, `offline` |
| `language` / `locale` / `timezone` | Locale info |
| `screen_width` / `screen_height` | Screen dimensions |
| `idfv` | Identifier for Vendor |
| `utm_*` | Attribution parameters (when set) |

## Architecture

```
┌──────────────────────────────────────────────┐
│                SwiftAnalytics                │
│                                              │
│  track() ──► Timeline Pipeline               │
│              │                               │
│              ├── Before plugins (filter)      │
│              ├── Enrichment plugins (enrich)  │
│              └── Destination plugins (store)  │
│                       │                      │
│                  SAEventStore (SQLite)        │
│                       │                      │
│                  SAUploader (HTTP batch)      │
│                       │                      │
│              Your Analytics Server           │
└──────────────────────────────────────────────┘
```

## License

MIT
