import Foundation
import Testing
@testable import AscendFit

@Suite("Grouped execution and recorded identity")
struct ExecutionExpansionTests {
    @Test("Group position determines round order, including unequal and added sets")
    func groupedRounds() throws {
        let groupID = UUID()
        let a = try movement("A", count: 2, group: ExerciseGroup(id: groupID, kind: .circuit, position: 1))
        let b = try movement("B", count: 1, group: ExerciseGroup(id: groupID, kind: .circuit, position: 0))
        let c = try movement("C", count: 1)
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Circuit", exercises: [a, b, c]))
        try session.handle(.start)
        let extra = PlannedSet(prescription: .bodyweight(reps: try RepTarget(exact: 8)))
        try session.handle(.addSet(exerciseID: b.id, set: extra))
        #expect(session.executionOrder.map(\.set.id) == [b.sets[0].id, a.sets[0].id, extra.id, a.sets[1].id, c.sets[0].id])
        try session.handle(.skipSet(plannedSetID: a.sets[0].id))
        let restored = try WorkoutSession(id: session.id, plan: session.plan, replaying: session.events)
        #expect(restored.executionOrder.map(\.set.id) == session.executionOrder.map(\.set.id))
        #expect(restored.skippedSetIDs == [a.sets[0].id])
        #expect(session.groupRound(for: a.sets[1].id) == 2)
        #expect(restored.groupRound(for: a.sets[1].id) == 2)
        #expect(restored.groupRound(for: extra.id) == 2)
        #expect(restored.groupRound(for: c.sets[0].id) == nil)
    }

    @Test("Replacement preserves completed movement identity through edit, undo, and replay")
    func recordedIdentity() throws {
        let original = try movement("Original", count: 3)
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Replacement", exercises: [original]))
        let result = SetResult.bodyweight(reps: try CompletedReps(8))
        let firstReplacement = try ExerciseDefinition(name: "Replacement one")
        let secondReplacement = try ExerciseDefinition(name: "Replacement two")
        try session.handle(.start)
        try session.handle(.completeSet(plannedSetID: original.sets[0].id, result: result, effort: nil, notes: nil))
        try session.handle(.replaceExercise(plannedExerciseID: original.id, replacement: firstReplacement))
        let completedID = try #require(session.completedSets.first?.id)
        try session.handle(.editSet(completedSetID: completedID, result: .bodyweight(reps: CompletedReps(9)), effort: nil, notes: nil))
        try session.handle(.completeSet(plannedSetID: original.sets[1].id, result: result, effort: nil, notes: nil))
        try session.handle(.replaceExercise(plannedExerciseID: original.id, replacement: secondReplacement))
        #expect(session.exerciseDefinition(for: original.sets[0].id) == original.exercise)
        #expect(session.exerciseDefinition(for: original.sets[1].id) == firstReplacement)
        #expect(session.exerciseDefinition(for: original.sets[2].id) == secondReplacement)
        try session.handle(.undoLastSet)
        #expect(session.exerciseDefinition(for: original.sets[1].id) == secondReplacement)
        try session.handle(.completeSet(plannedSetID: original.sets[1].id, result: result, effort: nil, notes: nil))
        let restored = try WorkoutSession(id: session.id, plan: session.plan, replaying: session.events)
        #expect(restored == session)
        #expect(restored.exerciseDefinition(for: original.sets[0].id) == original.exercise)
        #expect(restored.exerciseDefinition(for: original.sets[1].id) == secondReplacement)
    }

    @Test("Paused rest freezes remaining time across relaunch and repeated pauses")
    func restPauseRecovery() throws {
        let exercise = try movement("Timed rest", count: 2)
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Rest", exercises: [exercise]))
        let start = Date(timeIntervalSince1970: 100)
        try session.handle(.start, at: start)
        try session.handle(.startRest(duration: RestDuration(seconds: 90)), at: start)
        try session.handle(.pause, at: start.addingTimeInterval(30))
        session = try WorkoutSession(id: session.id, plan: session.plan, replaying: session.events)
        try session.handle(.resume, at: start.addingTimeInterval(300))
        #expect(session.status == .resting(deadline: start.addingTimeInterval(360)))
        try session.handle(.pause, at: start.addingTimeInterval(320))
        try session.handle(.resume, at: start.addingTimeInterval(500))
        #expect(session.status == .resting(deadline: start.addingTimeInterval(540)))
        #expect(try WorkoutSession(id: session.id, plan: session.plan, replaying: session.events) == session)
    }

    @Test("Advanced manual set prescriptions preserve ranges, assistance, units, and optional targets")
    func advancedManualPrescriptions() throws {
        let catalog = try #require(ExerciseCatalog.exercises.first)
        var draft = ManualSetDraft(catalog: catalog)
        draft.kind = .assisted
        draft.reps = 6
        draft.usesRepRange = true
        draft.upperReps = 10
        draft.load = 20
        #expect(try draft.prescription(unit: .kilograms) == .assistedBodyweight(reps: RepTarget(lower: 6, upper: 10), assistance: Load(amount: 20, unit: .kilograms)))
        draft.upperReps = 5
        #expect(throws: DomainValidationError.self) { try draft.prescription(unit: .kilograms) }
        // A discarded optional load from another type is irrelevant to distance/bodyweight.
        draft.load = -20
        draft.includesLoad = true
        draft.kind = .bodyweight
        draft.usesRepRange = false
        #expect(try draft.prescription(unit: .pounds) == .bodyweight(reps: RepTarget(exact: 6)))
        draft.kind = .distance
        draft.distance = 2.5
        draft.distanceUnit = .miles
        draft.includesDuration = true
        draft.seconds = 900
        draft.effortKind = "RPE"
        draft.effort = 7.5
        #expect(try draft.prescription(unit: .pounds) == .distance(distance: ExerciseDistance(amount: 2.5, unit: .miles), durationTarget: ExerciseDuration(seconds: 900)))
        #expect(try draft.effortTarget() == .rpe(RPE(7.5)))
        draft.kind = .amrap
        draft.includesLoad = false
        #expect(try draft.prescription(unit: .pounds) == .amrap(load: nil))
        let weighted = try #require(ExerciseCatalog.exercises.first(where: { $0.id == 1 }))
        let plank = try #require(ExerciseCatalog.exercises.first(where: { $0.id == 49 }))
        let carry = try #require(ExerciseCatalog.exercises.first(where: { $0.id == 100 }))
        let distance = SetPrescription.distance(distance: try ExerciseDistance(amount: 20, unit: .meters), durationTarget: nil)
        #expect(!weighted.supportsReplacement(for: .bodyweight(reps: try RepTarget(exact: 8))))
        #expect(!plank.supportsReplacement(for: distance))
        #expect(carry.supportsReplacement(for: distance))
        let copy = draft.copy()
        #expect(copy.id != draft.id)
        #expect(try copy.prescription(unit: .pounds) == draft.prescription(unit: .pounds))
    }

    private func movement(_ name: String, count: Int, group: ExerciseGroup? = nil) throws -> PlannedExercise {
        try PlannedExercise(exercise: ExerciseDefinition(name: name), sets: (0..<count).map { _ in
            PlannedSet(prescription: .bodyweight(reps: try RepTarget(exact: 8)))
        }, group: group)
    }
}
