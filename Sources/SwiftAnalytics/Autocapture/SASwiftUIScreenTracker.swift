#if canImport(SwiftUI)
import SwiftUI
import Foundation

/// SwiftUI ViewModifier for tracking screen views.
///
/// Usage:
/// ```swift
/// NavigationStack {
///     HomeView()
///         .saTrackScreen("Home")
/// }
/// ```
@available(iOS 15.0, *)
public struct SAScreenViewModifier: ViewModifier {
    let screenName: String
    let screenClass: String?
    let additionalProperties: SAProperties?

    public func body(content: Content) -> some View {
        content
            .onAppear {
                trackScreenView()
            }
    }

    private func trackScreenView() {
        var properties: SAProperties = [
            "screen_name": screenName,
            "screen_class": screenClass ?? screenName,
        ]

        if let additionalProperties {
            for (key, value) in additionalProperties {
                properties[key] = value
            }
        }

        SwiftAnalytics.shared?.track(
            SAConstants.EventType.screenViewed,
            eventProperties: properties
        )
    }
}

// MARK: - View Extension

@available(iOS 15.0, *)
public extension View {

    /// Track a screen view when this view appears.
    /// - Parameters:
    ///   - name: The screen name to report.
    ///   - screenClass: Optional class name (defaults to screen name).
    ///   - properties: Additional properties to include in the event.
    func saTrackScreen(
        _ name: String,
        screenClass: String? = nil,
        properties: SAProperties? = nil
    ) -> some View {
        self.modifier(SAScreenViewModifier(
            screenName: name,
            screenClass: screenClass,
            additionalProperties: properties
        ))
    }
}

// MARK: - Navigation Destination Tracker

/// Automatically tracks screen views when NavigationStack destination changes.
///
/// Usage:
/// ```swift
/// NavigationStack {
///     List(items) { item in
///         NavigationLink(value: item) { Text(item.name) }
///     }
///     .navigationDestination(for: Item.self) { item in
///         ItemDetailView(item: item)
///             .saTrackScreen("Item Detail", properties: ["item_id": item.id])
///     }
/// }
/// ```
@available(iOS 16.0, *)
public struct SANavigationTracker<Content: View>: View {
    let screenName: String
    let content: () -> Content

    public init(_ screenName: String, @ViewBuilder content: @escaping () -> Content) {
        self.screenName = screenName
        self.content = content
    }

    public var body: some View {
        content()
            .onAppear {
                SwiftAnalytics.shared?.track(
                    SAConstants.EventType.screenViewed,
                    eventProperties: ["screen_name": screenName, "screen_class": screenName]
                )
            }
    }
}
#endif
