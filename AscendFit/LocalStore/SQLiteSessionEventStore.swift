import Foundation
import SQLite3

enum LocalStoreError: Error, Equatable, Sendable {
    case couldNotOpen
    case sqlite(message: String)
    case invalidStoredText
}

private final class ManagedSQLiteConnection: @unchecked Sendable {
    let rawValue: OpaquePointer

    init(_ rawValue: OpaquePointer) {
        self.rawValue = rawValue
    }

    deinit {
        sqlite3_close(rawValue)
    }
}

actor SQLiteSessionEventStore: SessionEventStore, PlannedWorkoutStore {
    private let database: ManagedSQLiteConnection
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(url: URL) throws {
        var connection: OpaquePointer?
        guard sqlite3_open_v2(
            url.path,
            &connection,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let connection else {
            if let connection { sqlite3_close(connection) }
            throw LocalStoreError.couldNotOpen
        }

        database = ManagedSQLiteConnection(connection)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970

        do {
            try Self.execute(
                on: connection,
                sql: "PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;"
            )
            try Self.migrate(connection)
        } catch {
            throw error
        }
    }

    func saveScheduledWorkout(_ plan: WorkoutPlan) throws {
        let statement = try prepare(
            "INSERT OR REPLACE INTO scheduled_workout (slot, plan_id, plan_json) VALUES (1, ?, ?);"
        )
        defer { sqlite3_finalize(statement) }
        try bind(plan.id.uuidString, at: 1, to: statement)
        try bind(encodedText(plan), at: 2, to: statement)
        try stepDone(statement)
    }

    func loadScheduledWorkout() throws -> WorkoutPlan? {
        let statement = try prepare("SELECT plan_json FROM scheduled_workout WHERE slot = 1;")
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE { return nil }
        guard result == SQLITE_ROW else { throw Self.sqliteError(database.rawValue) }
        return try decodeColumn(0, from: statement)
    }

    func create(_ session: WorkoutSession) throws {
        let planJSON = try encodedText(session.plan)
        let statement = try prepare(
            "INSERT OR IGNORE INTO workout_sessions (id, plan_json) VALUES (?, ?);"
        )
        defer { sqlite3_finalize(statement) }

        try bind(session.id.uuidString, at: 1, to: statement)
        try bind(planJSON, at: 2, to: statement)
        try stepDone(statement)
    }

    func append(_ event: SessionEvent) throws {
        let eventJSON = try encodedText(event)
        try Self.execute(on: database.rawValue, sql: "BEGIN IMMEDIATE TRANSACTION;")

        do {
            let statement = try prepare(
                """
                INSERT OR IGNORE INTO session_events (
                    id, workout_session_id, sequence_number, event_json
                ) VALUES (
                    ?, ?,
                    (SELECT COALESCE(MAX(sequence_number) + 1, 0)
                     FROM session_events WHERE workout_session_id = ?),
                    ?
                );
                """
            )
            defer { sqlite3_finalize(statement) }

            try bind(event.id.uuidString, at: 1, to: statement)
            try bind(event.sessionID.uuidString, at: 2, to: statement)
            try bind(event.sessionID.uuidString, at: 3, to: statement)
            try bind(eventJSON, at: 4, to: statement)
            try stepDone(statement)
            if case .started = event.kind,
               sqlite3_changes(database.rawValue) > 0,
               let session = try load(sessionID: event.sessionID) {
                // Consume only this plan, in the same transaction as its start event.
                let consume = try prepare("DELETE FROM scheduled_workout WHERE plan_id = ?;")
                defer { sqlite3_finalize(consume) }
                try bind(session.plan.id.uuidString, at: 1, to: consume)
                try stepDone(consume)
            }
            try Self.execute(on: database.rawValue, sql: "COMMIT;")
        } catch {
            try? Self.execute(on: database.rawValue, sql: "ROLLBACK;")
            throw error
        }
    }

    func load(sessionID: UUID) throws -> WorkoutSession? {
        let planStatement = try prepare(
            "SELECT plan_json FROM workout_sessions WHERE id = ?;"
        )
        defer { sqlite3_finalize(planStatement) }
        try bind(sessionID.uuidString, at: 1, to: planStatement)

        guard sqlite3_step(planStatement) == SQLITE_ROW else { return nil }
        let plan: WorkoutPlan = try decodeColumn(0, from: planStatement)

        let eventStatement = try prepare(
            """
            SELECT event_json FROM session_events
            WHERE workout_session_id = ?
            ORDER BY sequence_number ASC;
            """
        )
        defer { sqlite3_finalize(eventStatement) }
        try bind(sessionID.uuidString, at: 1, to: eventStatement)

        var events: [SessionEvent] = []
        while sqlite3_step(eventStatement) == SQLITE_ROW {
            events.append(try decodeColumn(0, from: eventStatement))
        }

        return try WorkoutSession(id: sessionID, plan: plan, replaying: events)
    }

    func loadLatestUnfinished() throws -> WorkoutSession? {
        let statement = try prepare(
            "SELECT id FROM workout_sessions ORDER BY rowid DESC;"
        )
        defer { sqlite3_finalize(statement) }

        var sessionIDs: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_text(statement, 0),
                  let sessionID = UUID(uuidString: String(cString: bytes))
            else {
                throw LocalStoreError.invalidStoredText
            }
            sessionIDs.append(sessionID)
        }

        for sessionID in sessionIDs {
            if let session = try load(sessionID: sessionID), !session.status.isTerminal,
               session.status != .notStarted {
                return session
            }
        }
        return nil
    }

    func loadCompletedSessions() throws -> [WorkoutSession] {
        let statement = try prepare(
            "SELECT id FROM workout_sessions ORDER BY rowid DESC;"
        )
        defer { sqlite3_finalize(statement) }

        var sessions: [WorkoutSession] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_text(statement, 0),
                  let sessionID = UUID(uuidString: String(cString: bytes))
            else {
                throw LocalStoreError.invalidStoredText
            }
            guard let session = try load(sessionID: sessionID),
                  case .completed = session.status else { continue }
            sessions.append(session)
        }

        return sessions.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func deleteCompletedSession(sessionID: UUID) throws {
        guard let session = try load(sessionID: sessionID) else { return }
        guard case .completed = session.status else {
            throw LocalStoreError.sqlite(message: "Only completed workouts can be deleted from history.")
        }
        // Foreign-key cascading removes its event stream in the same statement.
        let statement = try prepare("DELETE FROM workout_sessions WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        try bind(sessionID.uuidString, at: 1, to: statement)
        try stepDone(statement)
    }

    func deleteAllWorkoutData() throws {
        guard try loadLatestUnfinished() == nil else {
            throw LocalStoreError.sqlite(message: "Finish or discard the active workout before deleting workout data.")
        }
        try Self.execute(on: database.rawValue, sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try Self.execute(on: database.rawValue, sql: "DELETE FROM scheduled_workout; DELETE FROM workout_sessions;")
            try Self.execute(on: database.rawValue, sql: "COMMIT;")
        } catch {
            try? Self.execute(on: database.rawValue, sql: "ROLLBACK;")
            throw error
        }
    }

    private static func migrate(_ database: OpaquePointer) throws {
        var versionStatement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &versionStatement, nil) == SQLITE_OK,
              let versionStatement
        else {
            throw sqliteError(database)
        }
        defer { sqlite3_finalize(versionStatement) }

        guard sqlite3_step(versionStatement) == SQLITE_ROW else {
            throw sqliteError(database)
        }
        let version = sqlite3_column_int(versionStatement, 0)
        guard (0...2).contains(version) else {
            throw LocalStoreError.sqlite(message: "Unsupported local database version: \(version)")
        }
        if version == 0 {
            try execute(
                on: database,
                sql: """
                BEGIN IMMEDIATE TRANSACTION;
                CREATE TABLE workout_sessions (
                    id TEXT PRIMARY KEY NOT NULL,
                    plan_json TEXT NOT NULL
                );
                CREATE TABLE session_events (
                    id TEXT PRIMARY KEY NOT NULL,
                    workout_session_id TEXT NOT NULL
                        REFERENCES workout_sessions(id) ON DELETE CASCADE,
                    sequence_number INTEGER NOT NULL,
                    event_json TEXT NOT NULL,
                    UNIQUE (workout_session_id, sequence_number)
                );
                CREATE INDEX session_events_replay_order
                    ON session_events (workout_session_id, sequence_number);
                PRAGMA user_version = 1;
                COMMIT;
                """
            )
        }

        if version < 2 {
            try execute(on: database, sql: """
                BEGIN IMMEDIATE TRANSACTION;
                CREATE TABLE scheduled_workout (
                    slot INTEGER PRIMARY KEY CHECK (slot = 1),
                    plan_id TEXT NOT NULL,
                    plan_json TEXT NOT NULL
                );
                PRAGMA user_version = 2;
                COMMIT;
                """)
        }
    }

    private func encodedText<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw LocalStoreError.invalidStoredText
        }
        return text
    }

    private func decodeColumn<T: Decodable>(
        _ column: Int32,
        from statement: OpaquePointer
    ) throws -> T {
        guard let bytes = sqlite3_column_text(statement, column) else {
            throw LocalStoreError.invalidStoredText
        }
        let data = Data(String(cString: bytes).utf8)
        return try decoder.decode(T.self, from: data)
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database.rawValue, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw Self.sqliteError(database.rawValue)
        }
        return statement
    }

    private func bind(
        _ value: String,
        at index: Int32,
        to statement: OpaquePointer
    ) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw Self.sqliteError(database.rawValue)
        }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw Self.sqliteError(database.rawValue)
        }
    }

    private static func execute(on database: OpaquePointer, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw LocalStoreError.sqlite(message: message)
        }
    }

    private static func sqliteError(_ database: OpaquePointer) -> LocalStoreError {
        .sqlite(message: String(cString: sqlite3_errmsg(database)))
    }
}

private extension WorkoutSession {
    var completedAt: Date? {
        if case let .completed(date) = status { date } else { nil }
    }
}
