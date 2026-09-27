import Foundation
import Testing
@testable import AscendFit

struct ImportSourcePersistenceTests {
    @Test("Imported source survives scheduled-plan handoff, session recovery and export without losing whitespace")
    func sourceFollowsPlan() async throws {
        let raw = "  {\n  \"notes\": \"Stop if the twinge returns.\"\n}\n  "
        let source = ImportSource(kind: .workoutPlanFile, originalText: raw)
        let set = PlannedSet(prescription: .bodyweight(reps: try RepTarget(exact: 8)))
        let exercise = try PlannedExercise(exercise: ExerciseDefinition(name: "Bodyweight Squat"), sets: [set])
        let plan = try WorkoutPlan(title: "Imported", exercises: [exercise], importSource: source)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.sqlite")
        let store = try SQLiteSessionEventStore(url: url)
        try await store.saveScheduledWorkout(plan)
        #expect(try await store.loadScheduledWorkout()?.importSource?.originalText == raw)
        let coordinator = try await WorkoutSessionCoordinator.create(session: WorkoutSession(plan: plan), store: store)
        let date = Date(timeIntervalSince1970: 100)
        try await coordinator.handle(.start, at: date)
        try await coordinator.handle(.completeSet(plannedSetID: set.id,
            result: .bodyweight(reps: CompletedReps(8)), effort: nil, notes: nil), at: date)
        let finished = try await coordinator.handle(.finish(notes: nil), at: date)
        let reopened = try SQLiteSessionEventStore(url: url)
        let loaded = try await reopened.load(sessionID: finished.id)
        let recovered = try #require(loaded)
        #expect(recovered.plan.importSource == source)
        let export = WorkoutDataExport(entries: [try WorkoutHistoryEntry(session: recovered)])
        #expect(export.workouts.first?.session.plan.importSource?.originalText == raw)
        #expect(String(decoding: try export.csvData(), as: UTF8.self).contains("workoutPlanFile"))

        // Older plans have no source field; preserve additive compatibility.
        let encoded = try JSONEncoder().encode(plan)
        let decodedObject = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        var object = try #require(decodedObject)
        object.removeValue(forKey: "importSource")
        let old = try JSONDecoder().decode(WorkoutPlan.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.importSource == nil)
        #expect(old.exercises == plan.exercises)
    }
}
