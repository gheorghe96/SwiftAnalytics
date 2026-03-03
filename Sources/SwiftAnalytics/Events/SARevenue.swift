import Foundation

/// Revenue event builder for in-app purchase tracking.
public final class SARevenue {

    public var productId: String?
    public var price: Double = 0
    public var quantity: Int = 1
    public var revenueType: String?
    public var currency: String = "USD"
    public var receipt: Data?

    public init() {}

    /// Computed revenue: price × quantity
    public var revenue: Double {
        price * Double(quantity)
    }

    /// Whether this revenue event is valid (has required fields).
    public var isValid: Bool {
        price != 0
    }

    /// Convert to event properties dictionary for the $revenue event.
    func toEventProperties() -> SAProperties {
        var props = SAProperties()

        if let productId {
            props[SAConstants.RevenueKey.productId] = productId
        }
        props[SAConstants.RevenueKey.price] = price
        props[SAConstants.RevenueKey.quantity] = quantity
        props[SAConstants.RevenueKey.revenue] = revenue
        props[SAConstants.RevenueKey.currency] = currency

        if let revenueType {
            props[SAConstants.RevenueKey.revenueType] = revenueType
        }

        if let receipt {
            props[SAConstants.RevenueKey.receipt] = receipt.base64EncodedString()
            props[SAConstants.RevenueKey.receiptType] = "ios"
        }

        return props
    }

    /// Create an SAEvent from this revenue object.
    func toEvent() -> SAEvent {
        var event = SAEvent(eventType: SAConstants.EventType.revenue)
        event.eventProperties = toEventProperties()
        return event
    }
}
