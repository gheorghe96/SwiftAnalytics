import Foundation
import SQLite3

/// SQLite-backed event queue for offline storage and reliable delivery.
/// All operations are serialized on a dedicated dispatch queue.
final class SAEventStore {

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.swiftanalytics.eventstore", qos: .utility)
    private let dbPath: String

    // Prepared statements (cached for performance)
    private var insertStmt: OpaquePointer?
    private var selectStmt: OpaquePointer?
    private var deleteStmt: OpaquePointer?
    private var countStmt: OpaquePointer?
    private var updateStatusStmt: OpaquePointer?

    init(apiKey: String) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        self.dbPath = (documentsPath as NSString).appendingPathComponent("sa_events_\(apiKey).sqlite3")
        queue.sync { self.openDatabase() }
    }

    /// For testing with in-memory database
    init(inMemory: Bool = true) {
        self.dbPath = inMemory ? ":memory:" : ""
        queue.sync { self.openDatabase() }
    }

    deinit {
        queue.sync {
            finalizeStatements()
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
        }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            SALogger.error("Failed to open SQLite database: \(String(cString: sqlite3_errmsg(db)))")
            return
        }

        // Set PRAGMAs for performance
        execute("PRAGMA journal_mode = WAL")
        execute("PRAGMA synchronous = NORMAL")
        execute("PRAGMA cache_size = -4000")

        // Create tables
        execute("""
            CREATE TABLE IF NOT EXISTS sa_events (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                insert_id     TEXT    NOT NULL UNIQUE,
                event_json    TEXT    NOT NULL,
                created_at    INTEGER NOT NULL,
                attempt_count INTEGER NOT NULL DEFAULT 0,
                last_attempt  INTEGER,
                upload_status TEXT    NOT NULL DEFAULT 'pending'
                              CHECK(upload_status IN ('pending','uploading','failed'))
            )
        """)

        execute("""
            CREATE INDEX IF NOT EXISTS idx_sa_events_status
            ON sa_events(upload_status, created_at)
        """)

        execute("""
            CREATE INDEX IF NOT EXISTS idx_sa_events_created
            ON sa_events(created_at)
        """)

        prepareStatements()
    }

    private func prepareStatements() {
        // Insert
        let insertSQL = "INSERT OR IGNORE INTO sa_events (insert_id, event_json, created_at) VALUES (?, ?, ?)"
        sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil)

        // Select pending events
        let selectSQL = """
            SELECT id, insert_id, event_json, attempt_count
            FROM sa_events
            WHERE upload_status IN ('pending', 'failed')
            ORDER BY created_at ASC
            LIMIT ?
        """
        sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil)

        // Delete by IDs
        // Note: We'll build dynamic SQL for batch deletes since SQLite doesn't support array params

        // Count
        let countSQL = "SELECT COUNT(*) FROM sa_events WHERE upload_status IN ('pending', 'failed')"
        sqlite3_prepare_v2(db, countSQL, -1, &countStmt, nil)

        // Update status
        let updateSQL = "UPDATE sa_events SET upload_status = ?, attempt_count = attempt_count + 1, last_attempt = ? WHERE id = ?"
        sqlite3_prepare_v2(db, updateSQL, -1, &updateStatusStmt, nil)
    }

    private func finalizeStatements() {
        if insertStmt != nil { sqlite3_finalize(insertStmt); insertStmt = nil }
        if selectStmt != nil { sqlite3_finalize(selectStmt); selectStmt = nil }
        if deleteStmt != nil { sqlite3_finalize(deleteStmt); deleteStmt = nil }
        if countStmt != nil { sqlite3_finalize(countStmt); countStmt = nil }
        if updateStatusStmt != nil { sqlite3_finalize(updateStatusStmt); updateStatusStmt = nil }
    }

    // MARK: - Public API

    /// Insert a single event into the queue.
    func insert(event: SAEvent) {
        queue.async { [weak self] in
            self?.performInsert(event: event)
        }
    }

    /// Insert a single event synchronously (for flush-on-background).
    func insertSync(event: SAEvent) {
        queue.sync {
            performInsert(event: event)
        }
    }

    /// Fetch a batch of pending events for upload.
    func fetchPending(limit: Int, completion: @escaping ([StoredEvent]) -> Void) {
        queue.async { [weak self] in
            let events = self?.performFetchPending(limit: limit) ?? []
            completion(events)
        }
    }

    /// Fetch pending events synchronously.
    func fetchPendingSync(limit: Int) -> [StoredEvent] {
        queue.sync {
            performFetchPending(limit: limit)
        }
    }

    /// Delete events by their database IDs (after successful upload).
    func delete(ids: [Int64]) {
        guard !ids.isEmpty else { return }
        queue.async { [weak self] in
            self?.performDelete(ids: ids)
        }
    }

    /// Update the upload status of an event.
    func updateStatus(id: Int64, status: SAUploadStatus) {
        queue.async { [weak self] in
            self?.performUpdateStatus(id: id, status: status)
        }
    }

    /// Get the count of pending events.
    func pendingCount(completion: @escaping (Int) -> Void) {
        queue.async { [weak self] in
            let count = self?.performPendingCount() ?? 0
            completion(count)
        }
    }

    /// Get count synchronously.
    func pendingCountSync() -> Int {
        queue.sync {
            performPendingCount()
        }
    }

    /// Remove events older than the given age.
    func pruneOlderThan(maxAgeMs: Int64) {
        let cutoff = Int64(Date().timeIntervalSince1970 * 1000) - maxAgeMs
        queue.async { [weak self] in
            self?.execute("DELETE FROM sa_events WHERE created_at < \(cutoff)")
        }
    }

    /// Trim the queue to maxQueueDepth by removing oldest events.
    func trimToSize(_ maxSize: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            let count = performPendingCount()
            if count > maxSize {
                let excess = count - maxSize
                self.execute("""
                    DELETE FROM sa_events WHERE id IN (
                        SELECT id FROM sa_events ORDER BY created_at ASC LIMIT \(excess)
                    )
                """)
            }
        }
    }

    /// Clear all events.
    func clear() {
        queue.async { [weak self] in
            self?.execute("DELETE FROM sa_events")
        }
    }

    // MARK: - Internal Implementations

    private func performInsert(event: SAEvent) {
        guard let stmt = insertStmt else { return }
        guard let jsonData = event.toJSONData(),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            SALogger.error("Failed to serialize event to JSON")
            return
        }

        sqlite3_reset(stmt)
        sqlite3_bind_text(stmt, 1, (event.insertId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (jsonString as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 3, event.time)

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            SALogger.error("Failed to insert event: \(errMsg)")
        }
    }

    private func performFetchPending(limit: Int) -> [StoredEvent] {
        guard let stmt = selectStmt else { return [] }

        sqlite3_reset(stmt)
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var events = [StoredEvent]()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let insertId = String(cString: sqlite3_column_text(stmt, 1))
            let jsonString = String(cString: sqlite3_column_text(stmt, 2))
            let attemptCount = Int(sqlite3_column_int(stmt, 3))

            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let event = SAEvent.fromJSON(json) {
                events.append(StoredEvent(
                    rowId: id,
                    insertId: insertId,
                    event: event,
                    attemptCount: attemptCount
                ))
            }
        }

        return events
    }

    private func performDelete(ids: [Int64]) {
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let sql = "DELETE FROM sa_events WHERE id IN (\(placeholders))"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }

        for (index, id) in ids.enumerated() {
            sqlite3_bind_int64(stmt, Int32(index + 1), id)
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            SALogger.error("Failed to delete events: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    private func performUpdateStatus(id: Int64, status: SAUploadStatus) {
        guard let stmt = updateStatusStmt else { return }

        sqlite3_reset(stmt)
        sqlite3_bind_text(stmt, 1, (status.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 2, Int64(Date().timeIntervalSince1970 * 1000))
        sqlite3_bind_int64(stmt, 3, id)

        if sqlite3_step(stmt) != SQLITE_DONE {
            SALogger.error("Failed to update event status: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func performPendingCount() -> Int {
        guard let stmt = countStmt else { return 0 }
        sqlite3_reset(stmt)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    // MARK: - SQL Helpers

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
            SALogger.error("SQL error: \(msg)")
            sqlite3_free(errMsg)
            return false
        }
        return true
    }
}

// MARK: - StoredEvent

/// Represents an event fetched from the SQLite store, with metadata.
struct StoredEvent {
    let rowId: Int64
    let insertId: String
    let event: SAEvent
    let attemptCount: Int
}
