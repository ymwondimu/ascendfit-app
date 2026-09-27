import Foundation

/// Versioned archival export. Session snapshots include the original plan and
/// event log; rows offer a convenient planned-versus-actual view without replay.
struct WorkoutDataExport: Codable, Sendable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let exportedAt: Date
    let dateEncoding: String
    let sourceMetadataAvailability: String
    let workouts: [Workout]

    struct Workout: Codable, Sendable {
        let session: WorkoutSession
        let summary: WorkoutSummary
        let sets: [SetRow]
    }

    struct SetRow: Codable, Sendable {
        let plannedExerciseID: UUID
        let originalExercise: ExerciseDefinition
        let performedExercise: ExerciseDefinition
        let originalSet: PlannedSet
        let adjustedTarget: SetResult?
        let effectiveRestSeconds: Int?
        let status: String
        let actual: CompletedSet?
    }

    init(entries: [WorkoutHistoryEntry], exportedAt: Date = Date()) {
        schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        dateEncoding = "millisecondsSince1970"
        sourceMetadataAvailability = entries.contains { $0.session.plan.importSource != nil }
            ? "Retained at session.plan.importSource for imported workouts; legacy/manual sources may be unavailable"
            : "Not retained on these legacy or manually created workout sessions"
        workouts = entries.map { entry in
            Workout(session: entry.session, summary: entry.summary, sets: entry.session.plan.exercises.flatMap { exercise in
                (exercise.sets + entry.session.addedSets[exercise.id, default: []]).map { set in
                    let actual = entry.session.completedSets.first { $0.plannedSetID == set.id }
                    return SetRow(
                        plannedExerciseID: exercise.id,
                        originalExercise: exercise.exercise,
                        performedExercise: entry.session.exerciseDefinition(for: set.id) ?? exercise.exercise,
                        originalSet: set,
                        adjustedTarget: entry.session.setResultOverrides[set.id],
                        effectiveRestSeconds: entry.session.restDuration(for: set.id)?.seconds,
                        status: actual != nil ? "completed" : entry.session.skippedSetIDs.contains(set.id) ? "skipped" : "not_completed",
                        actual: actual
                    )
                }
            })
        }
    }

    func jsonData() throws -> Data {
        let encoder = Self.encoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func csvData() throws -> Data {
        let encoder = Self.encoder()
        func json<T: Encodable>(_ value: T) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        let iso = ISO8601DateFormatter()
        var rows = [["schema_version", "session_id", "plan_id", "workout", "started_at", "ended_at", "workout_notes", "plan_notes", "planned_exercise_id", "original_exercise_id", "original_exercise", "performed_exercise_id", "performed_exercise", "equipment", "exercise_notes", "set_id", "role", "side", "status", "original_target", "original_set_json", "adjusted_target_json", "effective_rest_seconds", "completed_set_id", "completed_at", "actual_result", "actual_result_json", "effort_json", "set_notes", "source_metadata"]]
        for workout in workouts {
            for row in workout.sets {
                let actual = row.actual
                let exerciseNotes = workout.session.plan.exercises.first { $0.id == row.plannedExerciseID }?.notes
                rows.append([
                    String(schemaVersion), workout.session.id.uuidString, workout.session.plan.id.uuidString,
                    workout.session.plan.title, iso.string(from: workout.summary.startedAt), iso.string(from: workout.summary.endedAt),
                    workout.summary.notes ?? "", workout.session.plan.notes ?? "", row.plannedExerciseID.uuidString,
                    row.originalExercise.id.uuidString, row.originalExercise.name,
                    row.performedExercise.id.uuidString, row.performedExercise.name, row.performedExercise.equipment ?? "",
                    exerciseNotes ?? "", row.originalSet.id.uuidString, row.originalSet.role.rawValue, row.originalSet.side.rawValue,
                    row.status, row.originalSet.prescription.summaryText, try json(row.originalSet),
                    try row.adjustedTarget.map { try json($0) } ?? "", row.effectiveRestSeconds.map(String.init) ?? "",
                    actual?.id.uuidString ?? "", actual.map { iso.string(from: $0.completedAt) } ?? "",
                    actual?.result.summaryText ?? "", try actual.map { try json($0.result) } ?? "",
                    try actual?.effort.map { try json($0) } ?? "", actual?.notes ?? "", try workout.session.plan.importSource.map { try json($0) } ?? "Not retained for this workout"
                ])
            }
        }
        return Data((rows.map { $0.map(Self.csvCell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n").utf8)
    }

    static func csvCell(_ value: String) -> String {
        // Spreadsheet applications may execute formula-looking user text even
        // inside quoted CSV fields. A leading apostrophe forces text treatment.
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let unsafe = trimmed.first.map { "=+-@".contains($0) } ?? false
        let protected = unsafe || value.first == "\t" || value.first == "\r" ? "'" + value : value
        return "\"" + protected.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }
}
