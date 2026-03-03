#if canImport(UIKit)
import UIKit
import Foundation

/// Automatically tracks screen views via UIViewController swizzling.
final class SAScreenTracker: SAEventPlugin {

    private static var isSwizzled = false

    init() {
        super.init(type: .utility)
    }

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        SAScreenTracker.swizzleViewDidAppear()
    }

    override func teardown() {
        super.teardown()
    }

    // MARK: - Swizzling

    private static func swizzleViewDidAppear() {
        guard !isSwizzled else { return }
        isSwizzled = true

        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.sa_viewDidAppear(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            SALogger.error("Failed to swizzle viewDidAppear")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        SALogger.debug("Screen tracking swizzle installed")
    }
}

// MARK: - UIViewController Extension

extension UIViewController {

    @objc func sa_viewDidAppear(_ animated: Bool) {
        // Call original implementation (swizzled)
        sa_viewDidAppear(animated)

        // Skip system view controllers
        let className = String(describing: type(of: self))
        guard !SAScreenTracker.shouldSkip(className: className) else { return }

        // Determine screen name
        let screenName = self.sa_screenName
        let screenClass = className

        // Track screen view
        SwiftAnalytics.shared?.track(SAConstants.EventType.screenViewed, eventProperties: [
            "screen_name": screenName,
            "screen_class": screenClass
        ])
    }

    /// Determine a user-friendly screen name.
    var sa_screenName: String {
        // Use the title if set
        if let title, !title.isEmpty {
            return title
        }
        // Use navigation item title
        if let navTitle = navigationItem.title, !navTitle.isEmpty {
            return navTitle
        }
        // Fall back to class name with "Controller"/"ViewController" stripped
        let className = String(describing: type(of: self))
        return className
            .replacingOccurrences(of: "ViewController", with: "")
            .replacingOccurrences(of: "Controller", with: "")
    }
}

extension SAScreenTracker {

    /// System view controllers to skip tracking.
    static func shouldSkip(className: String) -> Bool {
        let skipPrefixes = [
            "UI", "_UI",                        // UIKit internals
            "UINavigationController",
            "UITabBarController",
            "UIPageViewController",
            "UISplitViewController",
            "UICompatibilityInputViewController",
            "UIInputWindowController",
            "UISystemInputAssistantViewController",
            "UIAlertController",
            "UIActivityViewController",
            "_SFSafariViewController",
            "SFSafariViewController",
        ]

        // Skip exact matches with known system controllers
        let exactSkips: Set<String> = [
            "UINavigationController",
            "UITabBarController",
            "UIPageViewController",
            "UISplitViewController",
            "UIInputWindowController",
        ]
        if exactSkips.contains(className) { return true }

        // Skip if starts with underscore (private Apple classes)
        if className.hasPrefix("_") { return true }

        // Skip UIKit internal controllers
        if className.hasPrefix("UICompatibility") || className.hasPrefix("UISystem") {
            return true
        }

        return false
    }
}
#endif
