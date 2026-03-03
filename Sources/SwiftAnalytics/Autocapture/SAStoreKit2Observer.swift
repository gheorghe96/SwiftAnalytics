import Foundation
import StoreKit

/// Auto-captures StoreKit 2 in-app purchase transactions.
/// Listens to `Transaction.updates` and emits `$revenue` events automatically.
@available(iOS 15.0, macOS 12.0, *)
final class SAStoreKit2Observer: SAEventPlugin {

    private var updateTask: Task<Void, Never>?

    init() {
        super.init(type: .utility)
    }

    override func setup(analytics: SwiftAnalytics) {
        super.setup(analytics: analytics)
        startObserving()
    }

    override func teardown() {
        updateTask?.cancel()
        updateTask = nil
        super.teardown()
    }

    // MARK: - Observation

    private func startObserving() {
        updateTask = Task(priority: .utility) { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                self?.handleVerificationResult(result)
            }
        }
        SALogger.info("StoreKit 2 transaction observer started")
    }

    private func handleVerificationResult(_ result: VerificationResult<Transaction>) {
        switch result {
        case .verified(let transaction):
            trackTransaction(transaction)
            Task { await transaction.finish() }
        case .unverified(let transaction, let error):
            SALogger.warn("Unverified transaction \(transaction.id): \(error.localizedDescription)")
            trackTransaction(transaction, verified: false)
        }
    }

    // MARK: - Track

    private func trackTransaction(_ transaction: Transaction, verified: Bool = true) {
        guard let analytics else { return }

        let revenue = SARevenue()
        revenue.productId = transaction.productID
        revenue.price = NSDecimalNumber(decimal: transaction.price ?? 0).doubleValue
        revenue.quantity = transaction.purchasedQuantity
        revenue.currency = Self.extractCurrency(from: transaction)

        switch transaction.productType {
        case .autoRenewable:
            revenue.revenueType = "subscription"
        case .nonRenewable:
            revenue.revenueType = "subscription"
        case .consumable:
            revenue.revenueType = "purchase"
        case .nonConsumable:
            revenue.revenueType = "purchase"
        default:
            revenue.revenueType = "purchase"
        }

        if transaction.revocationDate != nil {
            revenue.revenueType = "refund"
            revenue.price = -abs(revenue.price)
        }

        analytics.logRevenue(revenue)

        SALogger.info("StoreKit 2 transaction tracked: \(transaction.productID) — $\(revenue.revenue)")
    }

    // MARK: - Currency Extraction

    private static func extractCurrency(from transaction: Transaction) -> String {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            return transaction.currency?.identifier ?? "USD"
        }
        #if compiler(>=5.9)
        return transaction.currencyCode ?? "USD"
        #else
        return "USD"
        #endif
    }
}
