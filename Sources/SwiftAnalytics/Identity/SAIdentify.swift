import Foundation

/// Builds identify operations for updating user or group properties.
/// Supports all 10 Amplitude-compatible identify operations.
public final class SAIdentify {

    /// Internal storage: operation key → { property: value }
    private(set) var operations: [String: SAProperties] = [:]

    /// Whether clearAll was called — supersedes all other ops
    private(set) var hasClearAll: Bool = false

    public init() {}

    // MARK: - Operations

    /// SET — unconditional write. Overwrites existing value.
    @discardableResult
    public func set(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.set, property: property, value: value)
        return self
    }

    /// SET ONCE — write only if property has never been set.
    @discardableResult
    public func setOnce(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.setOnce, property: property, value: value)
        return self
    }

    /// ADD — increment or decrement a numeric property.
    @discardableResult
    public func add(_ property: String, value: any Numeric) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.add, property: property, value: value)
        return self
    }

    /// APPEND — add to end of array (duplicates allowed).
    @discardableResult
    public func append(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.append, property: property, value: value)
        return self
    }

    /// PREPEND — add to start of array.
    @discardableResult
    public func prepend(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.prepend, property: property, value: value)
        return self
    }

    /// POST INSERT — append only if value is not already in array.
    @discardableResult
    public func postInsert(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.postInsert, property: property, value: value)
        return self
    }

    /// PRE INSERT — prepend only if value is not already in array.
    @discardableResult
    public func preInsert(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.preInsert, property: property, value: value)
        return self
    }

    /// REMOVE — remove first occurrence of value from array.
    @discardableResult
    public func remove(_ property: String, value: Any) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.remove, property: property, value: value)
        return self
    }

    /// UNSET — delete a user property entirely.
    @discardableResult
    public func unset(_ property: String) -> SAIdentify {
        addOperation(SAConstants.IdentifyOp.unset, property: property, value: "-")
        return self
    }

    /// CLEAR ALL — delete ALL user properties. Irreversible.
    @discardableResult
    public func clearAll() -> SAIdentify {
        hasClearAll = true
        operations.removeAll()
        operations[SAConstants.IdentifyOp.clearAll] = ["-": "-"]
        return self
    }

    // MARK: - Internal

    /// Returns true if no operations have been added.
    public var isEmpty: Bool {
        operations.isEmpty
    }

    /// Convert operations to the user_properties format expected by the server.
    func toUserProperties() -> SAProperties {
        var result = SAProperties()
        for (opKey, props) in operations {
            result[opKey] = props
        }
        return result
    }

    // MARK: - Private

    private func addOperation(_ op: String, property: String, value: Any) {
        guard !hasClearAll else {
            SALogger.warn("Cannot add identify operations after clearAll()")
            return
        }

        guard !property.isEmpty else {
            SALogger.warn("Identify property name cannot be empty")
            return
        }

        // Don't allow conflicting ops on the same property
        for existingOp in operations.keys where existingOp != op {
            if operations[existingOp]?[property] != nil {
                SALogger.warn("Property '\(property)' already has operation '\(existingOp)', skipping '\(op)'")
                return
            }
        }

        if operations[op] == nil {
            operations[op] = [:]
        }
        operations[op]?[property] = value
    }
}
