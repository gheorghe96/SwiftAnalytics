import Foundation

/// Manages group analytics: group type/name assignments and group-level properties.
final class SAGroupManager {

    private let lock = NSLock()
    private var groups: SAProperties = [:]

    /// Get current group assignments.
    var currentGroups: SAProperties {
        lock.lock()
        defer { lock.unlock() }
        return groups
    }

    // MARK: - Group Assignment

    /// Set a group assignment. All subsequent events will include this group.
    func setGroup(groupType: String, groupName: Any) {
        lock.lock()
        defer { lock.unlock() }
        groups[groupType] = groupName
        SALogger.debug("Group set: \(groupType) = \(groupName)")
    }

    /// Remove a group assignment.
    func removeGroup(groupType: String) {
        lock.lock()
        defer { lock.unlock() }
        groups.removeValue(forKey: groupType)
    }

    /// Clear all group assignments.
    func clearGroups() {
        lock.lock()
        defer { lock.unlock() }
        groups.removeAll()
    }

    // MARK: - Group Identify

    /// Create a group identify event for setting properties on a group (not a user).
    func createGroupIdentifyEvent(groupType: String, groupName: String,
                                  identify: SAIdentify) -> SAEvent {
        var event = SAEvent(eventType: SAConstants.EventType.groupIdentify)
        event.groups = [groupType: groupName]
        event.groupProperties = identify.toUserProperties()
        return event
    }
}
