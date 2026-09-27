import Foundation

struct PreviousSetPerformance: Equatable, Sendable {
    let date: Date
    let result: SetResult

    static func find(
        exercise: ExerciseDefinition,
        set: PlannedSet,
        exerciseSets: [PlannedSet],
        history: [WorkoutHistoryEntry]
    ) -> PreviousSetPerformance? {
        // Compare the same position among sets of the same role and side.
        // A warm-up or opposite-side result must not become a working-set cue.
        let comparableSets = exerciseSets.filter { $0.role == set.role && $0.side == set.side }
        guard let position = comparableSets.firstIndex(where: { $0.id == set.id }) else { return nil }

        for entry in history.sorted(by: { $0.summary.endedAt > $1.summary.endedAt }) {
            let session = entry.session
            let matches = session.plan.exercises.filter { planned in
                (planned.sets + session.addedSets[planned.id, default: []]).contains { candidate in
                    guard let recorded = session.exerciseDefinition(for: candidate.id) else { return false }
                    return matchesIdentity(recorded, exercise)
                }
            }
            guard !matches.isEmpty else { continue }
            // Repeated exercise blocks do not have an unambiguous positional match.
            guard matches.count == 1, let previousExercise = matches.first else { return nil }
            let previousSets = (previousExercise.sets + session.addedSets[previousExercise.id, default: []])
                .filter { candidate in
                    candidate.role == set.role && candidate.side == set.side
                        && session.exerciseDefinition(for: candidate.id).map { matchesIdentity($0, exercise) } == true
                }
            guard position < previousSets.count,
                  let completed = session.completedSets.first(where: {
                      $0.plannedSetID == previousSets[position].id
                  }),
                  set.prescription.accepts(completed.result)
            else { return nil }

            return PreviousSetPerformance(date: entry.summary.endedAt, result: completed.result)
        }
        return nil
    }

    private static func matchesIdentity(_ lhs: ExerciseDefinition, _ rhs: ExerciseDefinition) -> Bool {
        lhs.id == rhs.id || (normalized(lhs.name) == normalized(rhs.name)
            && normalized(lhs.equipment) == normalized(rhs.equipment))
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
