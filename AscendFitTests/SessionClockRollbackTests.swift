import Foundation
import Testing
@testable import AscendFit

@Suite("Session clock rollback")
struct SessionClockRollbackTests {
    @Test("Restored workouts still log, pause, and finish after the wall clock moves backward")
    func rollbackDoesNotBlockRestoredCommands() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clock-rollback-\(UUID()).sqlite")
        let plan = try WorkoutPlan(title: "Clock rollback", exercises: [
            PlannedExercise(exercise: ExerciseDefinition(name: "Push-up"), sets: [
                PlannedSet(prescription: .bodyweight(reps: RepTarget(exact: 8))),
                PlannedSet(prescription: .bodyweight(reps: RepTarget(exact: 8)))
            ])
        ])
        let future = Date(timeIntervalSince1970: 20_000)
        let rolledBack = future.addingTimeInterval(-3_600)
        let store = try SQLiteSessionEventStore(url: url)
        let original = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: plan), store: store)
        let started = try await original.handle(.start, at: future)

        let reopened = try SQLiteSessionEventStore(url: url)
        let restored = try #require(await reopened.loadLatestUnfinished())
        #expect(restored == started)
        let coordinator = WorkoutSessionCoordinator(session: restored, store: reopened, wallClock: { rolledBack })
        let logged = try await coordinator.handle(.completeSet(
            plannedSetID: plan.exercises[0].sets[0].id,
            result: .bodyweight(reps: CompletedReps(8)), effort: nil, notes: "Recorded after clock change"
        ))
        #expect(logged.completedSets.count == 1)
        #expect(logged.events.last?.occurredAt == future)
        let paused = try await coordinator.handle(.pause)
        #expect(paused.status == .paused(resumeStatus: .active))
        let finished = try await coordinator.handle(.finish(notes: nil))
        #expect(finished.status.isTerminal)
        #expect(finished.events.allSatisfy { $0.occurredAt == future })
        #expect(try await reopened.load(sessionID: finished.id) == finished)

        // Explicit timestamps are still validated, rather than silently corrected.
        let strict = WorkoutSessionCoordinator(session: started, store: store, wallClock: { rolledBack })
        await #expect(throws: DomainValidationError.nonChronologicalEvent) {
            try await strict.handle(.pause, at: rolledBack)
        }
        #expect(await strict.currentSession() == started)
    }
}
