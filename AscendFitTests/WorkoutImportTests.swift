import Foundation
import Testing
@testable import AscendFit

private final class WorkoutImportFixtures: NSObject {}

struct WorkoutImportTests {
    @Test("Smart quotes introduced by iOS paste are repaired before JSON validation")
    func smartQuotePaste() throws {
        let original = try fixture("lower-a-ready")
        let pasted = original.replacingOccurrences(of: "\"", with: "“")
        let response = try WorkoutJSONImporter.decode(pasted)
        #expect(response.workouts.count == 1)
        #expect(response.source?.originalText == original)
    }

    @Test("The confirmed Lower A file produces all targets and exact source after explicit custom-name review")
    func confirmedWorkout() throws {
        let text = try fixture("lower-a-ready")
        var draft = try draft(text)
        #expect(throws: WorkoutImportError.self) { try draft.makePlan() }
        for exercise in draft.response!.workouts[0].exercises where draft.definition(for: exercise) == nil {
            draft.exerciseMappings[exercise.id] = try ExerciseDefinition(name: exercise.name, equipment: exercise.equipment)
        }
        let plan = try draft.makePlan()
        #expect(plan.title == "Lower Body")
        #expect(plan.exercises.count == 13)
        #expect(plan.exercises.flatMap(\.sets).count == 33)
        #expect(plan.importSource?.originalText == text)
        #expect(plan.importSource?.kind == .workoutPlanFile)
        #expect(plan.exercises[0].sets[0].prescription == .timed(duration: try ExerciseDuration(seconds: 300), load: nil))
        #expect(plan.exercises[3].sets[0].prescription == .weighted(reps: try RepTarget(exact: 10), load: try Load(amount: 45, unit: .pounds)))
        #expect(plan.exercises[5].sets[1].prescription == .weighted(reps: try RepTarget(lower: 3, upper: 4), load: try Load(amount: 135, unit: .pounds)))
        #expect(plan.notes?.contains("stop that exercise rather than trying to work through it.") == true)
        #expect(plan.exercises.flatMap(\.sets).allSatisfy { $0.restAfter == nil })
    }

    @Test("Imported focus follows exercise regions; only a user-edited name overrides it")
    func importedWorkoutTitles() throws {
        var draft = try draft(fixture("lower-a-ready"))
        var workout = try #require(draft.response?.workouts.first)
        var upper = workout.exercises[0]
        upper.name = "Bench Press"
        var lower = workout.exercises[1]
        lower.name = "Back Squat"
        var neutral = workout.exercises[2]
        neutral.name = "Plank"
        var unknown = workout.exercises[3]
        unknown.name = "Unlisted movement"

        workout.exercises = [upper, neutral]
        #expect(draft.title(for: workout) == "Upper Body")
        draft.exerciseMappings[upper.id] = try #require(ExerciseCatalog.exercises.first { $0.name == "Back Squat" }).definition
        #expect(draft.title(for: workout) == "Lower Body")
        draft.exerciseMappings.removeValue(forKey: upper.id)
        workout.exercises = [lower, neutral]
        #expect(draft.title(for: workout) == "Lower Body")
        workout.exercises = [upper, lower, neutral]
        #expect(draft.title(for: workout) == "Full Body")
        workout.exercises = [upper, unknown]
        #expect(draft.title(for: workout) == "Workout")
        neutral.name = "Rowing machine"
        lower.name = "Hamstring curl"
        workout.exercises = [lower, neutral]
        #expect(draft.title(for: workout) == "Lower Body")

        draft.setTitle("My Sunday Session", for: workout)
        let reopened = try JSONDecoder().decode(WorkoutImportDraft.self, from: JSONEncoder().encode(draft))
        #expect(reopened.title(for: workout) == "My Sunday Session")
        draft.setTitle("  ", for: workout)
        #expect(draft.title(for: workout) == "Lower Body")
    }

    @Test("Unresolved source cannot be acknowledged away, and incompatible targets are never silently dropped")
    func ambiguityAndTargets() throws {
        var review = try draft(fixture("lower-a-review"))
        review.resolvedIssueIDs = Set(review.response!.issues.map { $0.id.uuidString })
        #expect(throws: WorkoutImportError.self) { try review.makePlan() }
        var alternatives = try draft(fixture("lower-a-ready"))
        alternatives.response!.workouts[0].exercises[0].name = "Bike or Treadmill"
        alternatives.exerciseMappings[alternatives.response!.workouts[0].exercises[0].id] = try ExerciseDefinition(name: "Bike or Treadmill")
        #expect(throws: WorkoutImportError.self) { try alternatives.makePlan() }
        var reordered = try draft(fixture("lower-a-ready"))
        let groupID = UUID()
        reordered.response!.workouts[0].exercises[0].group = ImportedGroup(id: groupID, kind: "superset", position: 1)
        reordered.response!.workouts[0].exercises[1].group = ImportedGroup(id: groupID, kind: "superset", position: 0)
        #expect(throws: WorkoutImportError.self) { try reordered.makePlan() }
        var set = try draft(fixture("lower-a-ready")).response!.workouts[0].exercises[0].sets[0]
        set.reps = ImportedReps(min: 8, max: 8)
        #expect(throws: WorkoutImportError.self) { try set.plannedSet() }
        set.reps = nil
        set.load = ImportedLoad(amount: 20, unit: nil)
        #expect(throws: WorkoutImportError.self) { try set.plannedSet() }
    }

    @Test("File capture and pending review survive reopen and are removed with local import deletion")
    func fileAndDraftStorage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let raw = try fixture("lower-a-ready")
        let file = directory.appendingPathComponent("workout.json")
        try Data(raw.utf8).write(to: file)
        let captured = try WorkoutJSONImporter.readFile(file)
        var pending = try draft(captured)
        pending.exerciseMappings[pending.response!.workouts[0].exercises[0].id] = try ExerciseDefinition(name: "Stationary Bike")
        let store = try WorkoutImportStore(directory: directory.appendingPathComponent("drafts"))
        try store.save(pending)
        let saved = try store.load()
        let restored = try #require(saved)
        #expect(restored.originalText == raw)
        #expect(restored.selectedWorkoutID == pending.selectedWorkoutID)
        #expect(restored.exerciseMappings.count == 1)
        try store.deleteAll()
        #expect(try store.load() == nil)
        try Data(repeating: 65, count: WorkoutJSONImporter.maximumBytes + 1).write(to: file)
        #expect(throws: WorkoutImportError.self) { try WorkoutJSONImporter.readFile(file) }
    }

    private func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle(for: WorkoutImportFixtures.self).url(forResource: name + ".workout", withExtension: "json"))
        return try String(contentsOf: url, encoding: .utf8)
    }
    private func draft(_ text: String) throws -> WorkoutImportDraft {
        let response = try WorkoutJSONImporter.decode(text)
        var draft = WorkoutImportDraft()
        draft.originalText = text
        draft.sourceKind = .workoutPlanFile
        draft.response = response
        draft.selectedWorkoutID = response.workouts.first?.id
        return draft
    }
}
