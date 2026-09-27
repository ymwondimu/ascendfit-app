import Foundation
import SQLite3
import Testing
@testable import AscendFit

@Suite("Workout deletion")
struct WorkoutDeletionTests {
    @Test("Deleting one completed workout preserves its neighbor and scheduled plan after reopening")
    func singleDeletionPreservesOtherData() async throws {
        let fixture = try DeletionFixture()
        let store = try SQLiteSessionEventStore(url: fixture.url)
        let removed = try await fixture.completedSession(in: store)
        let retained = try await fixture.completedSession(in: store)
        try await store.saveScheduledWorkout(fixture.plan)

        try await store.deleteCompletedSession(sessionID: removed.id)
        let reopened = try SQLiteSessionEventStore(url: fixture.url)
        #expect(try await reopened.load(sessionID: removed.id) == nil)
        #expect(try await reopened.loadCompletedSessions() == [retained])
        #expect(try await reopened.loadScheduledWorkout() == fixture.plan)
        #expect(try fixture.count("session_events", where: "workout_session_id = '\(removed.id.uuidString)'") == 0)
        #expect(try fixture.count("session_events") == retained.events.count)
    }

    @Test("An active workout prevents single and all-workout deletion without losing data")
    func activeWorkoutRefusesDeletion() async throws {
        let fixture = try DeletionFixture()
        let store = try SQLiteSessionEventStore(url: fixture.url)
        let completed = try await fixture.completedSession(in: store)
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: fixture.plan), store: store)
        let active = try await coordinator.handle(.start, at: fixture.startedAt)
        try await store.saveScheduledWorkout(fixture.plan)

        await #expect(throws: LocalStoreError.self) {
            try await store.deleteCompletedSession(sessionID: active.id)
        }
        await #expect(throws: LocalStoreError.self) {
            try await store.deleteAllWorkoutData()
        }
        #expect(try await store.loadLatestUnfinished() == active)
        #expect(try await store.loadCompletedSessions() == [completed])
        #expect(try await store.loadScheduledWorkout() == fixture.plan)
    }

    @Test("Delete-all rolls back every table on failure and can then be retried")
    func failedDeletionRollsBackAndRetries() async throws {
        let fixture = try DeletionFixture()
        let store = try SQLiteSessionEventStore(url: fixture.url)
        let completed = try await fixture.completedSession(in: store)
        try await store.saveScheduledWorkout(fixture.plan)
        // The plan deletion runs first. Fail during the subsequent event cascade
        // to prove the transaction restores both earlier and cascading changes.
        try fixture.execute("""
            CREATE TRIGGER fail_delete BEFORE DELETE ON session_events
            BEGIN SELECT RAISE(ABORT, 'test deletion failure'); END;
            """)
        await #expect(throws: LocalStoreError.self) {
            try await store.deleteAllWorkoutData()
        }
        #expect(try await store.loadCompletedSessions() == [completed])
        #expect(try await store.loadScheduledWorkout() == fixture.plan)
        #expect(try fixture.count("session_events") == completed.events.count)

        try fixture.execute("DROP TRIGGER fail_delete;")
        try await store.deleteAllWorkoutData()
        let reopened = try SQLiteSessionEventStore(url: fixture.url)
        #expect(try await reopened.loadCompletedSessions().isEmpty)
        #expect(try await reopened.loadLatestUnfinished() == nil)
        #expect(try await reopened.loadScheduledWorkout() == nil)
        #expect(try fixture.count("workout_sessions") == 0)
        #expect(try fixture.count("session_events") == 0)
        #expect(try fixture.count("scheduled_workout") == 0)
    }
}

private struct DeletionFixture {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("delete-\(UUID()).sqlite")
    let startedAt = Date(timeIntervalSince1970: 50_000)
    let plan: WorkoutPlan

    init() throws {
        plan = try WorkoutPlan(title: "Deletion fixture", exercises: [
            PlannedExercise(exercise: ExerciseDefinition(name: "Push-up"), sets: [
                PlannedSet(prescription: .bodyweight(reps: RepTarget(exact: 8)))
            ])
        ])
    }

    func completedSession(in store: SQLiteSessionEventStore) async throws -> WorkoutSession {
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: plan), store: store)
        try await coordinator.handle(.start, at: startedAt)
        try await coordinator.handle(.completeSet(
            plannedSetID: plan.exercises[0].sets[0].id,
            result: .bodyweight(reps: CompletedReps(8)), effort: nil, notes: "Keep this exact note"
        ), at: startedAt.addingTimeInterval(5))
        return try await coordinator.handle(.finish(notes: "Workout note"), at: startedAt.addingTimeInterval(10))
    }

    func execute(_ sql: String) throws {
        try withConnection { connection in
            guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else {
                throw LocalStoreError.sqlite(message: String(cString: sqlite3_errmsg(connection)))
            }
        }
    }

    func count(_ table: String, where predicate: String = "1") throws -> Int {
        try withConnection { connection in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(connection, "SELECT COUNT(*) FROM \(table) WHERE \(predicate);", -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                throw LocalStoreError.sqlite(message: String(cString: sqlite3_errmsg(connection)))
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw LocalStoreError.sqlite(message: String(cString: sqlite3_errmsg(connection)))
            }
            return Int(sqlite3_column_int(statement, 0))
        }
    }

    private func withConnection<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        var connection: OpaquePointer?
        guard sqlite3_open(url.path, &connection) == SQLITE_OK, let connection else {
            if let connection { sqlite3_close(connection) }
            throw LocalStoreError.couldNotOpen
        }
        defer { sqlite3_close(connection) }
        return try operation(connection)
    }
}
