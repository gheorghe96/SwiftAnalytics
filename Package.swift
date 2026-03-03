// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftAnalytics",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),  // for unit tests on Mac
    ],
    products: [
        // Core SDK — always required
        .library(name: "SwiftAnalytics", targets: ["SwiftAnalytics"]),
        // Optional: Session Replay (heavier — separate target)
        .library(name: "SASessionReplay", targets: ["SASessionReplay"]),
        // Optional: A/B Experiments
        .library(name: "SAExperiment", targets: ["SAExperiment"]),
    ],
    dependencies: [
        // Zero external dependencies in core ✅
    ],
    targets: [
        // ── Core SDK ──────────────────────────────────────────────────────────
        .target(
            name: "SwiftAnalytics",
            dependencies: [],
            path: "Sources/SwiftAnalytics",
            linkerSettings: [
                .linkedLibrary("sqlite3")  // built into iOS — no external dep
            ]
        ),
        // ── Session Replay (optional module) ──────────────────────────────────
        .target(
            name: "SASessionReplay",
            dependencies: ["SwiftAnalytics"],
            path: "Sources/SASessionReplay"
        ),
        // ── Experiments (optional module) ─────────────────────────────────────
        .target(
            name: "SAExperiment",
            dependencies: ["SwiftAnalytics"],
            path: "Sources/SAExperiment"
        ),
        // ── Unit Tests ────────────────────────────────────────────────────────
        .testTarget(
            name: "SwiftAnalyticsTests",
            dependencies: ["SwiftAnalytics"],
            path: "Tests/SwiftAnalyticsTests"
        ),
    ]
)
