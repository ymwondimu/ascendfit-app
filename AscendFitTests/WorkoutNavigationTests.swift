import Foundation
import Testing
@testable import AscendFit

struct WorkoutNavigationTests {
    @Test("Selecting a later set survives SQLite recovery and resumes grouped order after logging")
    func selectedSetPersistsWithoutChangingPlan() async throws {
        let groupID = UUID()
        let target = SetPrescription.bodyweight(reps: try RepTarget(exact: 8))
        let first = try PlannedExercise(exercise: ExerciseDefinition(name: "A"), sets: [PlannedSet(prescription: target), PlannedSet(prescription: target)], group: ExerciseGroup(id: groupID, kind: .superset, position: 0))
        let second = try PlannedExercise(exercise: ExerciseDefinition(name: "B"), sets: [PlannedSet(prescription: target)], group: ExerciseGroup(id: groupID, kind: .superset, position: 1))
        let plan = try WorkoutPlan(title: "Grouped", exercises: [first, second])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("navigation-\(UUID()).sqlite")
        let store = try SQLiteSessionEventStore(url: url)
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: plan), store: store)
        try await coordinator.handle(.start)
        try await coordinator.handle(.selectNextSet(first.sets[1].id))
        let reopened = try SQLiteSessionEventStore(url: url)
        var session = try #require(await reopened.loadLatestUnfinished())
        #expect(session.nextPendingSetID == first.sets[1].id)
        #expect(session.plan == plan)
        try session.handle(.pause)
        #expect(throws: DomainValidationError.self) { try session.handle(.selectNextSet(second.sets[0].id)) }
        try session.handle(.resume)
        let note = "  Left side felt tight.\nStopped here.  "
        try session.handle(.completeSet(plannedSetID: first.sets[1].id, result: .bodyweight(reps: CompletedReps(8)), effort: .rpe(RPE(7.5)), notes: note))
        #expect(session.completedSets.first?.notes == note)
        #expect(session.completedSets.first?.effort == .rpe(try RPE(7.5)))
        #expect(session.nextPendingSetID == first.sets[0].id)
        #expect(throws: DomainValidationError.self) { try session.handle(.selectNextSet(first.sets[1].id)) }
        try session.handle(.selectNextSet(second.sets[0].id))
        try session.handle(.skipSet(plannedSetID: second.sets[0].id))
        #expect(session.nextPendingSetID == first.sets[0].id)
        #expect(throws: DomainValidationError.self) { try session.handle(.selectNextSet(second.sets[0].id)) }
        #expect(try WorkoutSession(id: session.id, plan: plan, replaying: session.events) == session)
    }
}
