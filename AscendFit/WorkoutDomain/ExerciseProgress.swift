import Foundation

struct ExercisePerformance: Identifiable, Sendable {
    var id: UUID { completed.id }
    let sessionID: UUID
    let date: Date
    let workoutTitle: String
    let exercise: ExerciseDefinition
    let plannedSet: PlannedSet
    let completed: CompletedSet

    /// Exact comparisons only: equipment, set type, role, side, reps and tempo
    /// must match. Different load units deliberately remain separate series.
    var comparison: (key: String, label: String, value: Decimal, unit: String)? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let tempo = plannedSet.tempo.flatMap { try? encoder.encode($0) }
            .map { String(decoding: $0, as: UTF8.self) } ?? "default"
        let context = "\(plannedSet.role.rawValue) · \(plannedSet.side.rawValue)"
        let tempoLabel = plannedSet.tempo.map { value in
            let phases = [value.eccentric, value.bottomPause, value.concentric, value.topPause].map { phase in
                switch phase {
                case let .controlled(seconds): return NSDecimalNumber(decimal: seconds).stringValue
                case .explosive: return "X"
                }
            }
            return " · Tempo " + phases.joined(separator: "–")
        } ?? ""
        switch completed.result {
        case let .weighted(reps, load):
            guard load.amount > 0 else { return nil }
            return ("weighted|\(reps.value)|\(load.unit.rawValue)|\(context)|\(tempo)",
                    "\(reps.value) reps · \(context) · \(load.unit.rawValue)" + tempoLabel, load.amount, load.unit.rawValue)
        case let .bodyweight(reps):
            return ("bodyweight|\(context)|\(tempo)", "Bodyweight · \(context)" + tempoLabel, Decimal(reps.value), "reps")
        default:
            return nil
        }
    }
}

struct ExerciseRecord: Identifiable, Sendable {
    var id: UUID { performance.id }
    let performance: ExercisePerformance
    let previousBest: Decimal
    let value: Decimal
    let unit: String
    let label: String
}

struct ExerciseProgress: Identifiable, Sendable {
    let id: String
    let exercise: ExerciseDefinition
    let performances: [ExercisePerformance]

    static func all(in history: [WorkoutHistoryEntry]) -> [ExerciseProgress] {
        var grouped: [String: [ExercisePerformance]] = [:]
        for entry in history {
            for completed in entry.session.completedSets {
                guard let exercise = entry.session.exerciseDefinition(for: completed.plannedSetID),
                      let set = entry.session.setDefinition(id: completed.plannedSetID) else { continue }
                let key = identity(exercise)
                grouped[key, default: []].append(ExercisePerformance(
                    sessionID: entry.id, date: entry.summary.endedAt, workoutTitle: entry.session.plan.title,
                    exercise: exercise, plannedSet: set, completed: completed
                ))
            }
        }
        return grouped.compactMap { key, performances in
            let sorted = performances.sorted {
                $0.date == $1.date ? $0.completed.completedAt > $1.completed.completedAt : $0.date > $1.date
            }
            guard let latest = sorted.first else { return nil }
            return ExerciseProgress(id: key, exercise: latest.exercise, performances: sorted)
        }.sorted { $0.exercise.name.localizedStandardCompare($1.exercise.name) == .orderedAscending }
    }

    static func identity(_ exercise: ExerciseDefinition) -> String {
        let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let equipment = (exercise.equipment ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(name)|\(equipment)"
    }

    /// A first observation establishes a baseline, never a "new best".
    /// Multiple qualifying sets within a workout produce one record per series.
    var records: [ExerciseRecord] {
        var best: [String: Decimal] = [:]
        var result: [ExerciseRecord] = []
        let days = Dictionary(grouping: performances, by: \.date)
        for date in days.keys.sorted() {
            let sessions = Dictionary(grouping: days[date, default: []], by: \.sessionID)
            var dailyBest = best
            for sessionID in sessions.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
                let comparable = sessions[sessionID, default: []].filter { $0.comparison != nil }
                let series = Dictionary(grouping: comparable, by: { $0.comparison!.key })
                for key in series.keys.sorted() {
                    let samples = series[key, default: []]
                    guard let strongest = samples.sorted(by: {
                        let lhs = $0.comparison!.value, rhs = $1.comparison!.value
                        return lhs == rhs ? $0.id.uuidString < $1.id.uuidString : lhs > rhs
                    }).first, let comparison = strongest.comparison else { continue }
                    if let previous = best[key], comparison.value > previous {
                        result.append(ExerciseRecord(performance: strongest, previousBest: previous,
                                                     value: comparison.value, unit: comparison.unit, label: comparison.label))
                    }
                    dailyBest[key] = max(dailyBest[key] ?? comparison.value, comparison.value)
                }
            }
            // Sessions with the same timestamp cannot establish order for one another.
            best = dailyBest
        }
        return result.sorted {
            if $0.performance.date != $1.performance.date { return $0.performance.date > $1.performance.date }
            if $0.label != $1.label { return $0.label < $1.label }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}


extension ExerciseProgress {
    static func recordLines(for sessionID: UUID, in history: [WorkoutHistoryEntry]) -> [String] {
        all(in: history).flatMap(\.records).filter { $0.performance.sessionID == sessionID }.map { record in
            let value = NSDecimalNumber(decimal: record.value).stringValue
            let previous = NSDecimalNumber(decimal: record.previousBest).stringValue
            let equipment = record.performance.exercise.equipment.map { " (\($0))" } ?? ""
            return "New best: \(record.performance.exercise.name)\(equipment) · \(value) \(record.unit) · \(record.label) (previous \(previous) \(record.unit))"
        }.sorted()
    }
}
