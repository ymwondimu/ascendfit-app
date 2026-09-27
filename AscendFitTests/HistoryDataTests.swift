import Foundation
import Testing
@testable import AscendFit

struct HistoryDataTests {
    @Test("Export preserves replayable session, original targets, actuals, notes and stable IDs")
    func losslessJSON() throws {
        let entry = try workout(load: 80, at: 100.125, notes: "Knee felt uncomfortable; stopped early")
        let export = WorkoutDataExport(entries: [entry], exportedAt: Date(timeIntervalSince1970: 200))
        let data = try export.jsonData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(WorkoutDataExport.self, from: data)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.workouts.count == 1)
        #expect(decoded.workouts[0].session == entry.session)
        let row = try #require(decoded.workouts[0].sets.first)
        #expect(row.originalSet.prescription == entry.session.plan.exercises[0].sets[0].prescription)
        #expect(row.actual?.id == entry.session.completedSets[0].id)
        #expect(row.actual?.notes == "Knee felt uncomfortable; stopped early")
        #expect(row.actual?.effort == .rpe(try RPE(8)))
        #expect(row.status == "completed")
        #expect(decoded.sourceMetadataAvailability.contains("Not retained"))
    }

    @Test("CSV quotes multiline notes and prevents formula execution in user text")
    func safeCSV() throws {
        let entry = try workout(load: 80, at: 100, notes: "  =HYPERLINK(\"example\")\nnext line")
        let csv = String(decoding: try WorkoutDataExport(entries: [entry]).csvData(), as: UTF8.self)
        // Raw nonblank notes survive recording; CSV adds only its formula guard.
        #expect(csv.contains("\"'  =HYPERLINK(\"\"example\"\")\nnext line\""))
        #expect(csv.contains(entry.session.id.uuidString))
        #expect(csv.contains("original_set_json"))
        #expect(csv.contains("effort_json"))
        for text in ["=1+1", " +1", "-1", "@SUM(A1)", "\ttext", "\rtext"] {
            #expect(WorkoutDataExport.csvCell(text).hasPrefix("\"'"))
        }
        #expect(WorkoutDataExport.csvCell("ordinary, \"note\"") == "\"ordinary, \"\"note\"\"\"")
    }

    @Test("Records require prior comparable work and do not mix reps, units, side or equipment")
    func exactRecords() throws {
        let baseline = try workout(load: 80, at: 100)
        let stronger = try workout(load: 85, at: 200)
        let pounds = try workout(load: 200, unit: .pounds, at: 300)
        let lowerReps = try workout(load: 100, reps: 3, at: 400)
        let left = try workout(load: 100, side: .left, at: 500)
        let dumbbell = try workout(load: 100, equipment: "Dumbbell", at: 600)
        let all = ExerciseProgress.all(in: [dumbbell, stronger, pounds, baseline, lowerReps, left])
        #expect(all.count == 2)
        let records = all.flatMap(\.records)
        #expect(records.count == 1)
        #expect(records[0].performance.sessionID == stronger.id)
        #expect(records[0].previousBest == 80)
        #expect(records[0].value == 85)
        #expect(ExerciseProgress.all(in: [stronger]).flatMap(\.records).isEmpty)
        // Deleting the previous baseline removes its inferred record comparison.
        #expect(ExerciseProgress.all(in: [pounds, stronger, lowerReps, left]).flatMap(\.records).isEmpty)
    }

    @Test("Tempo comparisons are deterministic and distinct tempo prescriptions stay separate")
    func deterministicTempo() throws {
        let tempo = Tempo(eccentric: .controlled(seconds: 3), bottomPause: .controlled(seconds: 1),
                          concentric: .explosive, topPause: .controlled(seconds: 0))
        let first = try workout(load: 80, tempo: tempo, at: 100)
        let next = try workout(load: 85, tempo: tempo, at: 200)
        let normal = try workout(load: 90, at: 300)
        let progress = try #require(ExerciseProgress.all(in: [first, next, normal]).first)
        #expect(progress.records.count == 1)
        #expect(progress.records[0].performance.sessionID == next.id)
        let sample = try #require(progress.performances.first { $0.sessionID == first.id })
        #expect(Set((0..<50).compactMap { _ in sample.comparison?.key }).count == 1)
        #expect(sample.comparison?.label.contains("Tempo 3–1–X–0") == true)
    }

    @Test("History aggregation and exports preserve exercise identity at each logged set")
    func replacementAttribution() throws {
        let squat = try ExerciseDefinition(name: "Back Squat", equipment: "Barbell")
        let press = try ExerciseDefinition(name: "Leg Press", equipment: "Machine")
        let target = SetPrescription.weighted(reps: try RepTarget(exact: 8), load: try Load(amount: 80, unit: .kilograms))
        let sets = [PlannedSet(prescription: target), PlannedSet(prescription: target)]
        let exercise = try PlannedExercise(exercise: squat, sets: sets)
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Legs", exercises: [exercise]))
        let date = Date(timeIntervalSince1970: 100)
        try session.handle(.start, at: date)
        let result = SetResult.weighted(reps: try CompletedReps(8), load: try Load(amount: 80, unit: .kilograms))
        try session.handle(.completeSet(plannedSetID: sets[0].id, result: result, effort: nil, notes: nil), at: date)
        try session.handle(.replaceExercise(plannedExerciseID: exercise.id, replacement: press), at: date)
        try session.handle(.completeSet(plannedSetID: sets[1].id, result: result, effort: nil, notes: nil), at: date)
        try session.handle(.finish(notes: nil), at: date)
        let entry = try WorkoutHistoryEntry(session: session)
        let progress = ExerciseProgress.all(in: [entry])
        #expect(entry.summary.modifiedSetCount == 1, "A replacement modifies the set even when reps and load stay unchanged")
        #expect(Set(progress.map { $0.exercise.name }) == ["Back Squat", "Leg Press"])
        #expect(progress.allSatisfy { $0.performances.count == 1 })
        let rows = WorkoutDataExport(entries: [entry]).workouts[0].sets
        #expect(rows.map { $0.performedExercise.name } == ["Back Squat", "Leg Press"])
        #expect(rows.allSatisfy { $0.originalExercise.name == "Back Squat" })
    }

    private func workout(
        load: Decimal, unit: MassUnit = .kilograms, reps: Int = 8,
        side: ExerciseSide = .bilateral, equipment: String = "Barbell", tempo: Tempo? = nil,
        at timestamp: TimeInterval, notes: String? = nil
    ) throws -> WorkoutHistoryEntry {
        let definition = try ExerciseDefinition(name: "Back Squat", equipment: equipment)
        let target = try PlannedSet(prescription: .weighted(reps: RepTarget(exact: 8), load: Load(amount: 70, unit: unit)), side: side, tempo: tempo)
        let exercise = try PlannedExercise(exercise: definition, sets: [target])
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Strength", exercises: [exercise], notes: "Plan note"))
        let date = Date(timeIntervalSince1970: timestamp)
        try session.handle(.start, at: date)
        try session.handle(.completeSet(plannedSetID: target.id,
            result: .weighted(reps: CompletedReps(reps), load: Load(amount: load, unit: unit)),
            effort: .rpe(RPE(8)), notes: notes), at: date)
        try session.handle(.finish(notes: "Workout note"), at: date)
        return try WorkoutHistoryEntry(session: session)
    }
}
