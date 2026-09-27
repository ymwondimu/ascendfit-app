import Foundation
import Testing
@testable import AscendFit

@Suite("WorkoutPlan v1 domain")
struct WorkoutDomainTests {
    @Test("Invalid rep ranges are rejected")
    func invalidRepRange() {
        #expect(throws: DomainValidationError.invalidRange(field: "reps")) {
            try RepTarget(lower: 12, upper: 8)
        }
    }

    @Test("A supported plan keeps set semantics through JSON")
    func planRoundTrip() throws {
        let reps = try RepTarget(lower: 8, upper: 10)
        let load = try Load(amount: 80, unit: .kilograms)
        let rest = try RestDuration(seconds: 120)
        let set = PlannedSet(
            prescription: .weighted(reps: reps, load: load),
            effortTarget: .rir(try RIR(2)),
            restAfter: rest
        )
        let exercise = try PlannedExercise(
            exercise: ExerciseDefinition(name: "Back Squat", aliases: ["Squat"]),
            sets: [set]
        )
        let plan = try WorkoutPlan(title: "Lower A", exercises: [exercise])

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: data)

        #expect(decoded == plan)
    }

    @Test("Unresolved required fields keep a draft out of Today")
    func unresolvedDraftIsNotReady() throws {
        let source = ImportSource(kind: .paste, originalText: "Squat 3 x 5")
        let issue = try UnresolvedField(
            path: "exercises[0].sets[0].load.unit",
            reason: "Choose pounds or kilograms"
        )
        let draft = WorkoutDraft(
            id: UUID(),
            createdAt: Date(),
            source: source,
            plan: nil,
            unresolvedFields: [issue]
        )

        #expect(!draft.isReadyToSchedule)
    }

    @Test("Imported future schema versions fail during decoding")
    func unsupportedSchemaVersion() throws {
        let exercise = try PlannedExercise(
            exercise: ExerciseDefinition(name: "Plank"),
            sets: [PlannedSet(prescription: .timed(duration: ExerciseDuration(seconds: 30), load: nil))]
        )
        let plan = try WorkoutPlan(title: "Core", exercises: [exercise])
        let data = try JSONEncoder().encode(plan)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["schemaVersion"] = 2
        let futureData = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(WorkoutPlan.self, from: futureData)
        }
    }
}
