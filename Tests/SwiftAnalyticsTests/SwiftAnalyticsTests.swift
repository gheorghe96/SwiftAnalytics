import Testing
import Foundation
@testable import SwiftAnalytics

// MARK: - SAEvent Tests

@Suite("SAEvent")
struct SAEventTests {

    @Test func createBasicEvent() {
        let event = SAEvent(eventType: "Button Tapped")
        #expect(event.eventType == "Button Tapped")
        #expect(event.time > 0)
        #expect(!event.insertId.isEmpty)
        #expect(event.platform == "iOS")
        #expect(event.osName == "ios")
        #expect(event.deviceBrand == "Apple")
    }

    @Test func createEventWithProperties() {
        let event = SAEvent(eventType: "Purchase", eventProperties: [
            "item": "sword",
            "price": 9.99,
            "quantity": 1
        ])
        #expect(event.eventProperties?["item"] as? String == "sword")
        #expect(event.eventProperties?["price"] as? Double == 9.99)
        #expect(event.eventProperties?["quantity"] as? Int == 1)
    }

    @Test func jsonSerialization() {
        var event = SAEvent(eventType: "Test Event")
        event.userId = "user_123"
        event.deviceId = "device_abc"
        event.sessionId = 1234567890
        event.eventProperties = ["key": "value", "count": 42]

        let json = event.toJSON()
        #expect(json["event_type"] as? String == "Test Event")
        #expect(json["user_id"] as? String == "user_123")
        #expect(json["device_id"] as? String == "device_abc")
        #expect(json["session_id"] as? Int64 == 1234567890)

        let props = json["event_properties"] as? [String: Any]
        #expect(props?["key"] as? String == "value")
        #expect(props?["count"] as? Int == 42)
    }

    @Test func jsonRoundTrip() {
        var original = SAEvent(eventType: "Round Trip")
        original.userId = "usr_1"
        original.deviceId = "dev_2"
        original.sessionId = 999
        original.eventProperties = ["nested": ["a": 1]]
        original.language = "en-US"
        original.timezone = "Europe/Chisinau"

        let json = original.toJSON()
        let restored = SAEvent.fromJSON(json)

        #expect(restored?.eventType == "Round Trip")
        #expect(restored?.userId == "usr_1")
        #expect(restored?.deviceId == "dev_2")
        #expect(restored?.sessionId == 999)
        #expect(restored?.language == "en-US")
        #expect(restored?.timezone == "Europe/Chisinau")
    }

    @Test func jsonDataRoundTrip() {
        var event = SAEvent(eventType: "Data Test")
        event.deviceId = "d1"
        event.eventProperties = ["x": true]

        let data = event.toJSONData()
        #expect(data != nil)

        let restored = SAEvent.fromJSONData(data!)
        #expect(restored?.eventType == "Data Test")
        #expect(restored?.deviceId == "d1")
    }

    @Test func sanitizeProperties() {
        let props: SAProperties = [
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "array": [1, 2, 3],
            "nested": ["key": "val"],
            "date": Date(timeIntervalSince1970: 0),
        ]
        let sanitized = SAEvent.sanitizeProperties(props)
        #expect(sanitized["string"] as? String == "hello")
        #expect(sanitized["int"] as? Int == 42)
        #expect(sanitized["double"] as? Double == 3.14)
        // Date should be converted to ISO 8601 string
        #expect(sanitized["date"] is String)
    }
}

// MARK: - SAEventBuilder Tests

@Suite("SAEventBuilder")
struct SAEventBuilderTests {

    @Test func basicBuilder() {
        let event = SAEventBuilder("Image Generated")
            .set("model", "flux-1.1-pro")
            .set("style", "photorealistic")
            .set("credits_used", 5)
            .build()

        #expect(event.eventType == "Image Generated")
        #expect(event.eventProperties?["model"] as? String == "flux-1.1-pro")
        #expect(event.eventProperties?["credits_used"] as? Int == 5)
    }

    @Test func builderWithBatchProperties() {
        let event = SAEventBuilder("Batch")
            .setProperties(["a": 1, "b": 2])
            .set("c", 3)
            .build()

        #expect(event.eventProperties?["a"] as? Int == 1)
        #expect(event.eventProperties?["b"] as? Int == 2)
        #expect(event.eventProperties?["c"] as? Int == 3)
    }
}

// MARK: - SAIdentify Tests

@Suite("SAIdentify")
struct SAIdentifyTests {

    @Test func setOperation() {
        let identify = SAIdentify()
        identify.set("plan", value: "pro")
        identify.set("name", value: "Gheorghe")

        let props = identify.toUserProperties()
        let setOps = props["$set"] as? [String: Any]
        #expect(setOps?["plan"] as? String == "pro")
        #expect(setOps?["name"] as? String == "Gheorghe")
    }

    @Test func setOnceOperation() {
        let identify = SAIdentify()
        identify.setOnce("signup_date", value: "2024-01-15")

        let props = identify.toUserProperties()
        let ops = props["$setOnce"] as? [String: Any]
        #expect(ops?["signup_date"] as? String == "2024-01-15")
    }

    @Test func addOperation() {
        let identify = SAIdentify()
        identify.add("total_images", value: 1)
        identify.add("credits", value: -5)

        let props = identify.toUserProperties()
        let ops = props["$add"] as? [String: Any]
        #expect(ops?["total_images"] as? Int == 1)
        #expect(ops?["credits"] as? Int == -5)
    }

    @Test func appendOperation() {
        let identify = SAIdentify()
        identify.append("features", value: "ai_eraser")

        let props = identify.toUserProperties()
        let ops = props["$append"] as? [String: Any]
        #expect(ops?["features"] as? String == "ai_eraser")
    }

    @Test func prependOperation() {
        let identify = SAIdentify()
        identify.prepend("recent", value: "Paywall")

        let props = identify.toUserProperties()
        let ops = props["$prepend"] as? [String: Any]
        #expect(ops?["recent"] as? String == "Paywall")
    }

    @Test func postInsertOperation() {
        let identify = SAIdentify()
        identify.postInsert("steps", value: "onboarding")

        let props = identify.toUserProperties()
        let ops = props["$postInsert"] as? [String: Any]
        #expect(ops?["steps"] as? String == "onboarding")
    }

    @Test func preInsertOperation() {
        let identify = SAIdentify()
        identify.preInsert("badges", value: "early_adopter")

        let props = identify.toUserProperties()
        let ops = props["$preInsert"] as? [String: Any]
        #expect(ops?["badges"] as? String == "early_adopter")
    }

    @Test func removeOperation() {
        let identify = SAIdentify()
        identify.remove("flags", value: "beta_v2")

        let props = identify.toUserProperties()
        let ops = props["$remove"] as? [String: Any]
        #expect(ops?["flags"] as? String == "beta_v2")
    }

    @Test func unsetOperation() {
        let identify = SAIdentify()
        identify.unset("temp_promo")

        let props = identify.toUserProperties()
        let ops = props["$unset"] as? [String: Any]
        #expect(ops?["temp_promo"] as? String == "-")
    }

    @Test func clearAllOperation() {
        let identify = SAIdentify()
        identify.set("plan", value: "pro")
        identify.clearAll()

        // After clearAll, only $clearAll should exist
        let props = identify.toUserProperties()
        #expect(props["$clearAll"] != nil)
        #expect(props["$set"] == nil)
        #expect(identify.hasClearAll)
    }

    @Test func emptyIdentify() {
        let identify = SAIdentify()
        #expect(identify.isEmpty)
    }

    @Test func conflictingOpsOnSameProperty() {
        let identify = SAIdentify()
        identify.set("plan", value: "pro")
        // This should be skipped — "plan" already has a $set op
        identify.add("plan", value: 1)

        let props = identify.toUserProperties()
        #expect(props["$set"] != nil)
        #expect(props["$add"] == nil)
    }
}

// MARK: - SARevenue Tests

@Suite("SARevenue")
struct SARevenueTests {

    @Test func basicRevenue() {
        let revenue = SARevenue()
        revenue.productId = "com.app.pro"
        revenue.price = 9.99
        revenue.quantity = 1
        revenue.revenueType = "subscription"
        revenue.currency = "USD"

        #expect(revenue.isValid)
        #expect(revenue.revenue == 9.99)

        let props = revenue.toEventProperties()
        #expect(props["$productId"] as? String == "com.app.pro")
        #expect(props["$price"] as? Double == 9.99)
        #expect(props["$quantity"] as? Int == 1)
        #expect(props["$revenue"] as? Double == 9.99)
        #expect(props["$revenueType"] as? String == "subscription")
        #expect(props["$currency"] as? String == "USD")
    }

    @Test func revenueWithQuantity() {
        let revenue = SARevenue()
        revenue.price = 4.99
        revenue.quantity = 3

        #expect(revenue.revenue == 14.97)
    }

    @Test func invalidRevenue() {
        let revenue = SARevenue()
        // Price defaults to 0
        #expect(!revenue.isValid)
    }

    @Test func revenueToEvent() {
        let revenue = SARevenue()
        revenue.productId = "com.app.coins"
        revenue.price = 1.99
        revenue.quantity = 1

        let event = revenue.toEvent()
        #expect(event.eventType == "$revenue")
        #expect(event.eventProperties?["$productId"] as? String == "com.app.coins")
    }

    @Test func revenueWithReceipt() {
        let revenue = SARevenue()
        revenue.price = 9.99
        revenue.receipt = Data("test_receipt".utf8)

        let props = revenue.toEventProperties()
        #expect(props["$receipt"] is String) // base64 encoded
        #expect(props["$receiptType"] as? String == "ios")
    }
}

// MARK: - SAEventStore Tests

@Suite("SAEventStore")
struct SAEventStoreTests {

    @Test func insertAndFetch() {
        let store = SAEventStore(inMemory: true)
        let event = SAEvent(eventType: "Test")

        store.insertSync(event: event)

        let pending = store.fetchPendingSync(limit: 10)
        #expect(pending.count == 1)
        #expect(pending[0].event.eventType == "Test")
    }

    @Test func insertMultipleAndFetch() {
        let store = SAEventStore(inMemory: true)

        for i in 0..<5 {
            var event = SAEvent(eventType: "Event_\(i)")
            event.time = Int64(i)
            store.insertSync(event: event)
        }

        let pending = store.fetchPendingSync(limit: 3)
        #expect(pending.count == 3)

        let all = store.fetchPendingSync(limit: 100)
        #expect(all.count == 5)
    }

    @Test func deleteEvents() {
        let store = SAEventStore(inMemory: true)

        let event1 = SAEvent(eventType: "E1")
        let event2 = SAEvent(eventType: "E2")
        store.insertSync(event: event1)
        store.insertSync(event: event2)

        let pending = store.fetchPendingSync(limit: 10)
        #expect(pending.count == 2)

        // Delete first event
        store.delete(ids: [pending[0].rowId])

        // Wait for async delete
        Thread.sleep(forTimeInterval: 0.1)

        let remaining = store.fetchPendingSync(limit: 10)
        #expect(remaining.count == 1)
        #expect(remaining[0].event.eventType == "E2")
    }

    @Test func pendingCount() {
        let store = SAEventStore(inMemory: true)

        #expect(store.pendingCountSync() == 0)

        store.insertSync(event: SAEvent(eventType: "A"))
        store.insertSync(event: SAEvent(eventType: "B"))

        #expect(store.pendingCountSync() == 2)
    }

    @Test func deduplication() {
        let store = SAEventStore(inMemory: true)

        var event = SAEvent(eventType: "Dup")
        event.insertId = "same-id"

        store.insertSync(event: event)
        store.insertSync(event: event) // Should be ignored (UNIQUE constraint)

        #expect(store.pendingCountSync() == 1)
    }
}

// MARK: - SAPersistence Tests

@Suite("SAPersistence")
struct SAPersistenceTests {

    @Test func deviceIdPersistence() {
        let defaults = UserDefaults(suiteName: "test.persistence.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)

        #expect(persistence.deviceId == nil)
        persistence.deviceId = "test_device"
        #expect(persistence.deviceId == "test_device")
    }

    @Test func userIdPersistence() {
        let defaults = UserDefaults(suiteName: "test.persistence.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)

        #expect(persistence.userId == nil)
        persistence.userId = "user_123"
        #expect(persistence.userId == "user_123")

        persistence.userId = nil
        #expect(persistence.userId == nil)
    }

    @Test func sessionIdPersistence() {
        let defaults = UserDefaults(suiteName: "test.persistence.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)

        #expect(persistence.sessionId == 0)
        persistence.sessionId = 1234567890
        #expect(persistence.sessionId == 1234567890)
    }

    @Test func eventSequence() {
        let defaults = UserDefaults(suiteName: "test.persistence.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)

        #expect(persistence.eventSequence == 0)
        let id1 = persistence.nextEventId()
        let id2 = persistence.nextEventId()
        let id3 = persistence.nextEventId()

        #expect(id1 == 1)
        #expect(id2 == 2)
        #expect(id3 == 3)
    }

    @Test func consentStatePersistence() {
        let defaults = UserDefaults(suiteName: "test.persistence.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)

        #expect(persistence.consentState == .unknown)
        persistence.consentState = .optedIn
        #expect(persistence.consentState == .optedIn)
        persistence.consentState = .optedOut
        #expect(persistence.consentState == .optedOut)
    }
}

// MARK: - SASessionManager Tests

@Suite("SASessionManager")
struct SASessionManagerTests {

    private func makeManager(sessionGapMs: Int = 300_000, trackEvents: Bool = false) -> (SASessionManager, SAPersistence) {
        let defaults = UserDefaults(suiteName: "test.session.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)
        let manager = SASessionManager(
            persistence: persistence,
            minTimeBetweenSessionsMillis: sessionGapMs,
            trackingSessionEvents: trackEvents
        )
        return (manager, persistence)
    }

    @Test func firstForegroundStartsSession() {
        let (manager, _) = makeManager()
        #expect(manager.sessionId == 0)

        let started = manager.handleForeground()
        #expect(started)
        #expect(manager.sessionId > 0)
    }

    @Test func touchSessionWithinWindow() {
        let (manager, _) = makeManager()
        manager.handleForeground()
        let sessionId = manager.sessionId

        let newSession = manager.touchSession()
        #expect(!newSession)
        #expect(manager.sessionId == sessionId)
    }

    @Test func forceNewSession() {
        let (manager, _) = makeManager()
        manager.handleForeground()
        let firstSession = manager.sessionId

        let started = manager.startNewSession()
        #expect(started)
        #expect(manager.sessionId != firstSession)
        #expect(manager.sessionId > firstSession)
    }

    @Test func sessionEventsEmitted() {
        var emittedEvents: [SAEvent] = []
        let (manager, _) = makeManager(trackEvents: true)
        manager.onSessionEvent = { event in
            emittedEvents.append(event)
        }

        manager.handleForeground()
        #expect(emittedEvents.count == 1)
        #expect(emittedEvents[0].eventType == SAConstants.EventType.sessionStart)
    }
}

// MARK: - SATrackingOptions Tests

@Suite("SATrackingOptions")
struct SATrackingOptionsTests {

    @Test func defaultsAllEnabled() {
        let options = SATrackingOptions()
        #expect(options.trackCarrier)
        #expect(options.trackDeviceModel)
        #expect(options.trackLanguage)
        #expect(options.trackOSVersion)
        #expect(options.trackCountry)
        #expect(options.trackCity)
        #expect(options.trackNetworkType)
        #expect(options.trackTimezone)
    }

    @Test func coppaDisablesIdentifiers() {
        let options = SATrackingOptions.forCOPPA()
        #expect(!options.trackIDFV)
        #expect(!options.trackIDFA)
        #expect(!options.trackCity)
        #expect(!options.trackIPAddress)
        #expect(!options.trackLatLng)
        #expect(!options.trackDMA)
        // These should still be on
        #expect(options.trackLanguage)
        #expect(options.trackOSVersion)
    }

    @Test func disableIndividualProperties() {
        var options = SATrackingOptions()
        options.disableTrackCarrier()
        options.disableTrackCity()

        #expect(!options.trackCarrier)
        #expect(!options.trackCity)
        #expect(options.trackCountry) // Not disabled
    }
}

// MARK: - SAGroupManager Tests

@Suite("SAGroupManager")
struct SAGroupManagerTests {

    @Test func setAndGetGroups() {
        let manager = SAGroupManager()

        manager.setGroup(groupType: "org", groupName: "acme")
        manager.setGroup(groupType: "plan", groupName: "enterprise")

        let groups = manager.currentGroups
        #expect(groups["org"] as? String == "acme")
        #expect(groups["plan"] as? String == "enterprise")
    }

    @Test func removeGroup() {
        let manager = SAGroupManager()
        manager.setGroup(groupType: "org", groupName: "acme")
        manager.removeGroup(groupType: "org")

        let groups = manager.currentGroups
        #expect(groups["org"] == nil)
    }

    @Test func clearGroups() {
        let manager = SAGroupManager()
        manager.setGroup(groupType: "a", groupName: "1")
        manager.setGroup(groupType: "b", groupName: "2")
        manager.clearGroups()

        #expect(manager.currentGroups.isEmpty)
    }

    @Test func groupIdentifyEvent() {
        let manager = SAGroupManager()
        let identify = SAIdentify()
        identify.set("industry", value: "fintech")

        let event = manager.createGroupIdentifyEvent(
            groupType: "org",
            groupName: "acme",
            identify: identify
        )

        #expect(event.eventType == "$groupidentify")
        #expect(event.groups?["org"] as? String == "acme")
        #expect(event.groupProperties != nil)
    }
}

// MARK: - SAConsentManager Tests

@Suite("SAConsentManager")
struct SAConsentManagerTests {

    @Test func defaultState() {
        let defaults = UserDefaults(suiteName: "test.consent.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)
        let manager = SAConsentManager(persistence: persistence)

        #expect(manager.state == .unknown)
        #expect(manager.isTrackingAllowed)
        #expect(!manager.isOptedOut)
    }

    @Test func optOut() {
        let defaults = UserDefaults(suiteName: "test.consent.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)
        let manager = SAConsentManager(persistence: persistence)

        manager.optOut()
        #expect(manager.state == .optedOut)
        #expect(!manager.isTrackingAllowed)
        #expect(manager.isOptedOut)
    }

    @Test func optIn() {
        let defaults = UserDefaults(suiteName: "test.consent.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)
        let manager = SAConsentManager(persistence: persistence)

        manager.optOut()
        manager.optIn()
        #expect(manager.state == .optedIn)
        #expect(manager.isTrackingAllowed)
    }

    @Test func consentCallback() {
        let defaults = UserDefaults(suiteName: "test.consent.\(UUID().uuidString)")!
        let persistence = SAPersistence(defaults: defaults)
        let manager = SAConsentManager(persistence: persistence)

        var receivedState: SAConsentState?
        manager.onConsentChanged = { state in
            receivedState = state
        }

        manager.optOut()
        #expect(receivedState == .optedOut)

        manager.optIn()
        #expect(receivedState == .optedIn)
    }
}

// MARK: - SAConfiguration Tests

@Suite("SAConfiguration")
struct SAConfigurationTests {

    @Test func defaultConfiguration() {
        let config = SAConfiguration(
            apiKey: "test_key",
            serverURL: "https://analytics.example.com"
        )

        #expect(config.apiKey == "test_key")
        #expect(config.flushIntervalMillis == 30_000)
        #expect(config.flushQueueSize == 30)
        #expect(config.maxQueueDepth == 1_000)
        #expect(config.minTimeBetweenSessionsMillis == 300_000)
        #expect(config.trackingSessionEvents)
        #expect(config.flushOnBackground)
        #expect(!config.uploadOnWifiOnly)
        #expect(!config.optOut)
        #expect(!config.enableSessionReplay)
        #expect(!config.enableRealtime)
    }

    @Test func customConfiguration() {
        let config = SAConfiguration(
            apiKey: "custom_key",
            serverURL: "https://custom.example.com",
            flushIntervalMillis: 10_000,
            flushQueueSize: 50,
            uploadOnWifiOnly: true,
            minTimeBetweenSessionsMillis: 600_000,
            logLevel: SALogLevel.debug
        )

        #expect(config.flushIntervalMillis == 10_000)
        #expect(config.flushQueueSize == 50)
        #expect(config.minTimeBetweenSessionsMillis == 600_000)
        #expect(config.uploadOnWifiOnly)
        #expect(config.logLevel == SALogLevel.debug)
    }
}

// MARK: - Plugin Timeline Tests

@Suite("SATimeline")
struct SATimelineTests {

    final class MockPlugin: SAEventPlugin {
        var executedEvents: [SAEvent] = []

        override func execute(event: SAEvent) -> SAEvent? {
            executedEvents.append(event)
            return event
        }
    }

    final class FilterPlugin: SAEventPlugin {
        let blockedType: String

        init(blockedType: String) {
            self.blockedType = blockedType
            super.init(type: .before)
        }

        override func execute(event: SAEvent) -> SAEvent? {
            if event.eventType == blockedType { return nil }
            return event
        }
    }

    @Test func pluginReceivesEvents() {
        let timeline = SATimeline()
        let plugin = MockPlugin(type: .enrichment)
        timeline.add(plugin: plugin)

        let event = SAEvent(eventType: "Test")
        timeline.process(event: event)

        #expect(plugin.executedEvents.count == 1)
        #expect(plugin.executedEvents[0].eventType == "Test")
    }

    @Test func beforePluginCanFilterEvents() {
        let timeline = SATimeline()
        let filter = FilterPlugin(blockedType: "Blocked")
        let destination = MockPlugin(type: .destination)

        timeline.add(plugin: filter)
        timeline.add(plugin: destination)

        timeline.process(event: SAEvent(eventType: "Allowed"))
        timeline.process(event: SAEvent(eventType: "Blocked"))

        #expect(destination.executedEvents.count == 1)
        #expect(destination.executedEvents[0].eventType == "Allowed")
    }

    @Test func pluginExecutionOrder() {
        let timeline = SATimeline()
        var order: [String] = []

        final class OrderPlugin: SAEventPlugin {
            let name: String
            let orderLog: UnsafeMutablePointer<[String]>

            init(type: SAPluginType, name: String, orderLog: UnsafeMutablePointer<[String]>) {
                self.name = name
                self.orderLog = orderLog
                super.init(type: type)
            }

            override func execute(event: SAEvent) -> SAEvent? {
                orderLog.pointee.append(name)
                return event
            }
        }

        let enrichment = OrderPlugin(type: .enrichment, name: "enrichment", orderLog: &order)
        let before = OrderPlugin(type: .before, name: "before", orderLog: &order)
        let dest = OrderPlugin(type: .destination, name: "destination", orderLog: &order)

        // Add in random order — should execute in type order
        timeline.add(plugin: dest)
        timeline.add(plugin: before)
        timeline.add(plugin: enrichment)

        timeline.process(event: SAEvent(eventType: "Test"))

        #expect(order == ["before", "enrichment", "destination"])
    }

    @Test func findPlugin() {
        let timeline = SATimeline()
        let plugin = MockPlugin(type: .enrichment)
        timeline.add(plugin: plugin)

        let found = timeline.find(pluginType: MockPlugin.self)
        #expect(found === plugin)
    }
}

// MARK: - Constants Tests

@Suite("SAConstants")
struct SAConstantsTests {

    @Test func eventTypes() {
        #expect(SAConstants.EventType.applicationInstalled == "[SA] Application Installed")
        #expect(SAConstants.EventType.screenViewed == "[SA] Screen Viewed")
        #expect(SAConstants.EventType.revenue == "$revenue")
        #expect(SAConstants.EventType.identify == "$identify")
    }

    @Test func defaults() {
        #expect(SAConstants.Defaults.flushIntervalMillis == 30_000)
        #expect(SAConstants.Defaults.flushQueueSize == 30)
        #expect(SAConstants.Defaults.maxQueueDepth == 1_000)
        #expect(SAConstants.Defaults.minTimeBetweenSessionsMillis == 300_000)
    }
}

// MARK: - Autocapture Options Tests

@Suite("SAAutocaptureOptions")
struct SAAutocaptureOptionsTests {

    @Test func allContainsEverything() {
        let all = SAAutocaptureOptions.all
        #expect(all.contains(.appLifecycle))
        #expect(all.contains(.sessions))
        #expect(all.contains(.screenViews))
        #expect(all.contains(.deepLinks))
        #expect(all.contains(.pushNotifications))
        #expect(all.contains(.networkType))
        #expect(all.contains(.crashes))
    }

    @Test func noneContainsNothing() {
        let none = SAAutocaptureOptions.none
        #expect(!none.contains(.appLifecycle))
        #expect(!none.contains(.sessions))
    }

    @Test func customCombination() {
        let custom: SAAutocaptureOptions = [.appLifecycle, .crashes]
        #expect(custom.contains(.appLifecycle))
        #expect(custom.contains(.crashes))
        #expect(!custom.contains(.screenViews))
    }
}
