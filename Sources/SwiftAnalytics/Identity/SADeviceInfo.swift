#if canImport(UIKit)
import UIKit
#endif
import Foundation
#if canImport(CoreTelephony)
import CoreTelephony
#endif
#if canImport(Network)
import Network
#endif

/// Collects device, app, and environment properties automatically.
final class SADeviceInfo {

    // MARK: - Cached Values (computed once)

    lazy var osVersion: String = {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #endif
    }()

    lazy var deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }()

    lazy var deviceFamily: String = {
        SADeviceInfo.humanReadableModel(deviceModel)
    }()

    lazy var appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }()

    lazy var appBuild: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }()

    lazy var bundleId: String = {
        Bundle.main.bundleIdentifier ?? ""
    }()

    lazy var language: String = {
        Locale.preferredLanguages.first ?? "en"
    }()

    lazy var localeIdentifier: String = {
        Locale.current.identifier
    }()

    lazy var timezoneIdentifier: String = {
        TimeZone.current.identifier
    }()

    lazy var screenWidth: Int = {
        #if canImport(UIKit)
        return Int(UIScreen.main.bounds.width)
        #else
        return 0
        #endif
    }()

    lazy var screenHeight: Int = {
        #if canImport(UIKit)
        return Int(UIScreen.main.bounds.height)
        #else
        return 0
        #endif
    }()

    lazy var screenScale: Double = {
        #if canImport(UIKit)
        return Double(UIScreen.main.scale)
        #else
        return 1.0
        #endif
    }()

    lazy var idfv: String? = {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString
        #else
        return nil
        #endif
    }()

    lazy var carrier: String? = {
        #if canImport(CoreTelephony) && os(iOS)
        let networkInfo = CTTelephonyNetworkInfo()
        if let carriers = networkInfo.serviceSubscriberCellularProviders,
           let first = carriers.values.first {
            return first.carrierName
        }
        return nil
        #else
        return nil
        #endif
    }()

    // MARK: - Network Monitoring

    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.swiftanalytics.network")
    private(set) var currentNetworkType: String = "unknown"
    private(set) var currentCellularTechnology: String?

    func startNetworkMonitoring() {
        #if canImport(Network)
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            self?.updateNetworkType(path: path)
        }
        pathMonitor?.start(queue: monitorQueue)
        #endif
    }

    func stopNetworkMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    #if canImport(Network)
    private func updateNetworkType(path: NWPath) {
        if path.status != .satisfied {
            currentNetworkType = "offline"
            currentCellularTechnology = nil
        } else if path.usesInterfaceType(.wifi) {
            currentNetworkType = "wifi"
            currentCellularTechnology = nil
        } else if path.usesInterfaceType(.cellular) {
            updateCellularType()
        } else if path.usesInterfaceType(.wiredEthernet) {
            currentNetworkType = "ethernet"
            currentCellularTechnology = nil
        } else {
            currentNetworkType = "unknown"
            currentCellularTechnology = nil
        }
    }
    #endif

    private func updateCellularType() {
        #if canImport(CoreTelephony) && os(iOS)
        let networkInfo = CTTelephonyNetworkInfo()
        if let radioTech = networkInfo.serviceCurrentRadioAccessTechnology?.values.first {
            switch radioTech {
            case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
                currentNetworkType = "cellular_5g"
                currentCellularTechnology = "NR"
            case CTRadioAccessTechnologyLTE:
                currentNetworkType = "cellular_4g"
                currentCellularTechnology = "LTE"
            case CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
                 CTRadioAccessTechnologyWCDMA:
                currentNetworkType = "cellular_3g"
                currentCellularTechnology = "HSDPA"
            case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyGPRS:
                currentNetworkType = "cellular_2g"
                currentCellularTechnology = "EDGE"
            default:
                currentNetworkType = "cellular"
                currentCellularTechnology = radioTech
            }
        } else {
            currentNetworkType = "cellular"
            currentCellularTechnology = nil
        }
        #else
        currentNetworkType = "cellular"
        currentCellularTechnology = nil
        #endif
    }

    // MARK: - Enrich Event

    /// Populate device, app, locale, and network fields on an event.
    func enrich(event: inout SAEvent, trackingOptions: SATrackingOptions) {
        event.platform = SAConstants.platform
        event.osName = SAConstants.osName
        event.deviceBrand = SAConstants.deviceBrand
        event.library = SAConstants.sdkLibrary

        if trackingOptions.trackOSVersion {
            event.osVersion = osVersion
        }
        if trackingOptions.trackDeviceModel {
            event.deviceModel = deviceModel
            event.deviceFamily = deviceFamily
        }
        if trackingOptions.trackScreenSize {
            event.screenWidth = screenWidth
            event.screenHeight = screenHeight
            event.screenDensity = screenScale
        }

        event.appVersion = appVersion
        event.appBuild = appBuild

        if trackingOptions.trackLanguage {
            event.language = language
        }
        if trackingOptions.trackLocale {
            event.locale = localeIdentifier
        }
        if trackingOptions.trackTimezone {
            event.timezone = timezoneIdentifier
        }
        if trackingOptions.trackCarrier {
            event.carrier = carrier
        }
        if trackingOptions.trackNetworkType {
            event.networkType = currentNetworkType
            event.cellularTechnology = currentCellularTechnology
        }
        if trackingOptions.trackIDFV {
            event.idfv = idfv
        }
    }

    // MARK: - Device Model Lookup

    /// Convert machine identifier to human-readable device name.
    static func humanReadableModel(_ identifier: String) -> String {
        let models: [String: String] = [
            // iPhone 15 series
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone15,4": "iPhone 15",
            // iPhone 14 series
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone14,7": "iPhone 14",
            // iPhone 13 series
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,2": "iPhone 13 Pro",
            // iPhone 12 series
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,2": "iPhone 12",
            "iPhone13,1": "iPhone 12 mini",
            // iPhone 11 series
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,1": "iPhone 11",
            // iPhone SE
            "iPhone14,6": "iPhone SE (3rd generation)",
            "iPhone12,8": "iPhone SE (2nd generation)",
            // iPhone 16 series
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            // iPad models (abbreviated)
            "iPad13,18": "iPad (10th generation)",
            "iPad13,19": "iPad (10th generation)",
            "iPad14,3":  "iPad Pro 11-inch (4th generation)",
            "iPad14,4":  "iPad Pro 11-inch (4th generation)",
            "iPad14,5":  "iPad Pro 12.9-inch (6th generation)",
            "iPad14,6":  "iPad Pro 12.9-inch (6th generation)",
            // Simulators
            "x86_64":    "Simulator (x86_64)",
            "arm64":     "Simulator (arm64)",
        ]
        return models[identifier] ?? identifier
    }
}
