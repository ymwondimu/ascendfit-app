import Foundation
import SQLite3
import Testing
@testable import AscendFit

@Suite("Local session event store")
struct LocalStoreTests {
    @Test("A failed completion preserves a resumable session and can be retried once")
    func failedCompletionCanRetry() async throws {
        let fixture = try LocalStoreFixture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("finish-\(UUID()).sqlite")
        let store = try SQLiteSessionEventStore(url: url)
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: fixture.plan), store: store)
        let started = try await coordinator.handle(.start, at: fixture.startedAt)
        try executeFixtureSQL("""
            CREATE TRIGGER fail_finish BEFORE INSERT ON session_events
            BEGIN SELECT RAISE(ABORT, 'test finish failure'); END;
            """, at: url)
        await #expect(throws: LocalStoreError.self) {
            try await coordinator.handle(.finish(notes: "My note"), at: fixture.startedAt.addingTimeInterval(10))
        }
        #expect(await coordinator.currentSession() == started)
        #expect(try await store.loadLatestUnfinished() == started)
        try executeFixtureSQL("DROP TRIGGER fail_finish;", at: url)
        let finished = try await coordinator.handle(.finish(notes: "My note"), at: fixture.startedAt.addingTimeInterval(11))
        #expect(finished.events.count == started.events.count + 1)
        #expect(try await store.loadCompletedSessions() == [finished])
        #expect(finished.completionNotes == "My note")
    }

    @Test("A scheduled plan survives reopening and is consumed only by its own start")
    func scheduledPlanHandoff() async throws {
        let fixture = try LocalStoreFixture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scheduled-\(UUID()).sqlite")
        let store = try SQLiteSessionEventStore(url: url)
        try await store.saveScheduledWorkout(fixture.plan)
        let reopened = try SQLiteSessionEventStore(url: url)
        #expect(try await reopened.loadScheduledWorkout() == fixture.plan)
        let session = WorkoutSession(plan: fixture.plan)
        try await reopened.create(session)
        #expect(try await reopened.loadLatestUnfinished() == nil)
        let coordinator = WorkoutSessionCoordinator(session: session, store: reopened)
        let started = try await coordinator.handle(.start, at: fixture.startedAt)
        #expect(try await store.loadScheduledWorkout() == nil)
        #expect(try await store.loadLatestUnfinished() == started)
        // A replayed start must not consume a newly scheduled workout.
        try await store.saveScheduledWorkout(fixture.plan)
        try await store.append(started.events[0])
        #expect(try await store.loadScheduledWorkout() == fixture.plan)
    }

    @Test("A failed plan handoff rolls back its start event and supports retry")
    func failedHandoffPreservesPlan() async throws {
        let fixture = try LocalStoreFixture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("handoff-\(UUID()).sqlite")
        let store = try SQLiteSessionEventStore(url: url)
        try await store.saveScheduledWorkout(fixture.plan)
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: fixture.plan), store: store)
        try executeFixtureSQL("""
            CREATE TRIGGER fail_consume BEFORE DELETE ON scheduled_workout
            BEGIN SELECT RAISE(ABORT, 'test write failure'); END;
            """, at: url)
        await #expect(throws: LocalStoreError.self) {
            try await coordinator.handle(.start, at: fixture.startedAt)
        }
        #expect(try await store.loadScheduledWorkout() == fixture.plan)
        #expect(try await store.loadLatestUnfinished() == nil)
        #expect(await coordinator.currentSession().events.isEmpty)
        try executeFixtureSQL("DROP TRIGGER fail_consume;", at: url)
        try await coordinator.handle(.start, at: fixture.startedAt)
        #expect(try await store.loadScheduledWorkout() == nil)
    }

    @Test("Version-one session data survives the scheduled-plan migration")
    func migrationPreservesSession() async throws {
        let fixture = try LocalStoreFixture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("migration-\(UUID()).sqlite")
        let store = try SQLiteSessionEventStore(url: url)
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: fixture.plan), store: store)
        let started = try await coordinator.handle(.start, at: fixture.startedAt)
        // The remaining tables are the unchanged version-one schema, with real event data.
        try executeFixtureSQL("DROP TABLE scheduled_workout; PRAGMA user_version = 1;", at: url)
        let migrated = try SQLiteSessionEventStore(url: url)
        #expect(try await migrated.loadLatestUnfinished() == started)
        try await migrated.saveScheduledWorkout(fixture.plan)
        #expect(try await migrated.loadScheduledWorkout() == fixture.plan)
    }

    @Test("Overlapping commands preserve every saved change and replay exactly")
    func overlappingCommandsRemainConsistent() async throws {
        let fixture = try LocalStoreFixture()
        let store = YieldingEventStore()
        let coordinator = WorkoutSessionCoordinator(
            session: WorkoutSession(id: fixture.sessionID, plan: fixture.plan),
            store: store
        )
        try await coordinator.handle(.start, at: fixture.startedAt)
        let exerciseID = fixture.plan.exercises[0].id
        let reps = try RepTarget(exact: 8)
        let sets = (0..<20).map { _ in
            PlannedSet(prescription: .bodyweight(reps: reps))
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for set in sets {
                group.addTask {
                    try await coordinator.handle(.addSet(exerciseID: exerciseID, set: set))
                }
            }
            try await group.waitForAll()
        }

        let current = await coordinator.currentSession()
        let events = await store.events
        let replayed = try WorkoutSession(
            id: fixture.sessionID, plan: fixture.plan, replaying: events
        )
        #expect(Set(current.addedSets[exerciseID, default: []].map(\.id)) == Set(sets.map(\.id)))
        #expect(events.count == sets.count + 1)
        #expect(current == replayed)
    }

    @Test("SQLite reconstructs a session from its ordered event stream")
    func sqliteRoundTrip() async throws {
        let fixture = try LocalStoreFixture()
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ascend-fit-\(UUID().uuidString).sqlite")
        let store = try SQLiteSessionEventStore(url: databaseURL)
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)
        try await store.create(session)

        let started = try session.handle(.start, at: fixture.startedAt)
        try await store.append(started)
        let completed = try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            ),
            at: fixture.startedAt.addingTimeInterval(10)
        )
        try await store.append(completed)

        let restored = try #require(await store.load(sessionID: fixture.sessionID))
        #expect(restored == session)
    }

    @Test("A failed append leaves the coordinator state unchanged")
    func persistenceFailureDoesNotPublishState() async throws {
        let fixture = try LocalStoreFixture()
        let coordinator = WorkoutSessionCoordinator(
            session: WorkoutSession(plan: fixture.plan),
            store: FailingEventStore()
        )

        do {
            _ = try await coordinator.handle(.start, at: fixture.startedAt)
            Issue.record("Expected the event write to fail")
        } catch StoreFixtureError.expectedFailure {
            // Expected.
        }

        let current = await coordinator.currentSession()
        #expect(current.status == .notStarted)
        #expect(current.events.isEmpty)

        let retried = try await coordinator.handle(.start, at: fixture.startedAt)
        #expect(retried.status == .active)
        #expect(retried.events.count == 1)
    }

    @Test("Completed sessions remain available for history")
    func completedSessionsLoadFromTheEventStore() async throws {
        let fixture = try LocalStoreFixture()
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ascend-fit-history-\(UUID().uuidString).sqlite")
        let store = try SQLiteSessionEventStore(url: databaseURL)
        let coordinator = try await WorkoutSessionCoordinator.create(
            session: WorkoutSession(id: fixture.sessionID, plan: fixture.plan),
            store: store
        )

        _ = try await coordinator.handle(.start, at: fixture.startedAt)
        _ = try await coordinator.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            ),
            at: fixture.startedAt.addingTimeInterval(10)
        )
        _ = try await coordinator.handle(.prepareToFinish, at: fixture.startedAt.addingTimeInterval(11))
        _ = try await coordinator.handle(.finish(notes: nil), at: fixture.startedAt.addingTimeInterval(12))

        let completed = try await store.loadCompletedSessions()
        #expect(completed.map(\.id) == [fixture.sessionID])
    }
}

private enum StoreFixtureError: Error {
    case expectedFailure
}

private actor YieldingEventStore: SessionEventStore {
    private(set) var events: [SessionEvent] = []

    func create(_: WorkoutSession) {}
    func append(_ event: SessionEvent) async {
        await Task.yield()
        events.append(event)
        await Task.yield()
    }
    func load(sessionID _: UUID) -> WorkoutSession? { nil }
    func loadLatestUnfinished() -> WorkoutSession? { nil }
    func loadCompletedSessions() -> [WorkoutSession] { [] }
}

private actor FailingEventStore: SessionEventStore {
    private var shouldFail = true
    func create(_: WorkoutSession) throws {}

    func append(_: SessionEvent) throws {
        if shouldFail {
            shouldFail = false
            throw StoreFixtureError.expectedFailure
        }
    }

    func load(sessionID _: UUID) throws -> WorkoutSession? {
        nil
    }

    func loadLatestUnfinished() throws -> WorkoutSession? {
        nil
    }

    func loadCompletedSessions() throws -> [WorkoutSession] {
        []
    }
}

private struct LocalStoreFixture {
    let sessionID = UUID()
    let startedAt = Date(timeIntervalSince1970: 10_000)
    let plannedSetID: UUID
    let plan: WorkoutPlan

    init() throws {
        plannedSetID = UUID()
        let set = try PlannedSet(
            id: plannedSetID,
            prescription: .weighted(
                reps: RepTarget(exact: 5),
                load: Load(amount: 100, unit: .kilograms)
            ),
            restAfter: RestDuration(seconds: 90)
        )
        let exercise = try PlannedExercise(
            exercise: ExerciseDefinition(name: "Back Squat"),
            sets: [set]
        )
        plan = try WorkoutPlan(title: "Lower A", exercises: [exercise])
    }
}

private func executeFixtureSQL(_ sql: String, at url: URL) throws {
    var connection: OpaquePointer?
    guard sqlite3_open(url.path, &connection) == SQLITE_OK, let connection else {
        throw LocalStoreError.couldNotOpen
    }
    defer { sqlite3_close(connection) }
    guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else {
        throw LocalStoreError.sqlite(message: String(cString: sqlite3_errmsg(connection)))
    }
}
