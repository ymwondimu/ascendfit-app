import Foundation

struct WorkoutSummary: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let workoutPlanID: UUID
    let startedAt: Date
    let endedAt: Date
    let activeDuration: TimeInterval
    let completedSetCount: Int
    let modifiedSetCount: Int
    let skippedSetCount: Int
    let volumeByUnit: [MassUnit: Decimal]
    let notes: String?
}

struct WorkoutHistoryEntry: Identifiable, Equatable, Sendable {
    let session: WorkoutSession
    let summary: WorkoutSummary

    var id: UUID { session.id }

    init(session: WorkoutSession) throws {
        self.session = session
        summary = try session.makeSummary()
    }

    var coachReadyText: String {
        session.coachReadyText(summary: summary)
    }

    func coachReadyText(recordLines: [String]) -> String {
        guard !recordLines.isEmpty else { return coachReadyText }
        return coachReadyText + "\n\nNew bests (comparable recorded sets):\n" + recordLines.joined(separator: "\n")
    }
}

extension WorkoutSession {
    func makeSummary() throws -> WorkoutSummary {
        guard
            let startedAt = events.first(where: { event in
                if case .started = event.kind { return true }
                return false
            })?.occurredAt,
            case let .completed(endedAt) = status
        else {
            throw DomainValidationError.summaryUnavailable
        }

        var pausedAt: Date?
        var pausedDuration: TimeInterval = 0

        for event in events {
            switch event.kind {
            case .paused:
                pausedAt = event.occurredAt
            case .resumed, .finishPrepared, .finished:
                if let pauseStart = pausedAt {
                    pausedDuration += event.occurredAt.timeIntervalSince(pauseStart)
                    pausedAt = nil
                }
            default:
                break
            }
        }

        // Older builds persisted a separate finishing step. Time awaiting recovery
        // after that step is not time spent training.
        let durationEnd = events.first { event in
            if case .finishPrepared = event.kind { return true }
            return false
        }?.occurredAt ?? endedAt
        let activeDuration = max(0, durationEnd.timeIntervalSince(startedAt) - pausedDuration)
        var modifiedSetCount = 0
        var volumeByUnit: [MassUnit: Decimal] = [:]

        for completedSet in completedSets {
            guard let plannedSet = setDefinition(id: completedSet.plannedSetID) else { continue }
            let originalExercise = plan.exercises.first { exercise in
                (exercise.sets + addedSets[exercise.id, default: []]).contains { $0.id == completedSet.plannedSetID }
            }?.exercise
            let performedExercise = exerciseDefinition(for: completedSet.plannedSetID)
            if !plannedSet.prescription.matches(completedSet.result)
                || originalExercise?.id != performedExercise?.id {
                modifiedSetCount += 1
            }
            if let volume = completedSet.result.volume {
                volumeByUnit[volume.unit, default: 0] += volume.amount
            }
        }

        return WorkoutSummary(
            id: id,
            sessionID: id,
            workoutPlanID: plan.id,
            startedAt: startedAt,
            endedAt: endedAt,
            activeDuration: activeDuration,
            completedSetCount: completedSets.count,
            modifiedSetCount: modifiedSetCount,
            skippedSetCount: skippedSetIDs.count,
            volumeByUnit: volumeByUnit,
            notes: completionNotes
        )
    }

    fileprivate func coachReadyText(summary: WorkoutSummary) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        var lines = [
            "Ascend Fit workout: \(plan.title)",
            "Completed: \(dateFormatter.string(from: summary.endedAt))",
            "Duration: \(summary.activeDuration.clockText)",
            "Sets: \(summary.completedSetCount) completed, \(summary.modifiedSetCount) modified, \(summary.skippedSetCount) skipped"
        ]

        if !summary.volumeByUnit.isEmpty {
            let volume = summary.volumeByUnit
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .map { "\($0.value.plainText) \($0.key.rawValue)" }
                .joined(separator: ", ")
            lines.append("Volume: \(volume)")
        }

        for exercise in plan.exercises {
            let exerciseName = exercise.exercise.name
            lines.append("")
            lines.append(exerciseName)
            let sets = exercise.sets + addedSets[exercise.id, default: []]
            for (index, set) in sets.enumerated() {
                if let completed = completedSets.first(where: { $0.plannedSetID == set.id }) {
                    var detail = "\(index + 1). \(completed.result.summaryText)"
                    if let actualExercise = exerciseDefinition(for: set.id), actualExercise.id != exercise.exercise.id {
                        detail += " · \(actualExercise.name) (replaces \(exercise.exercise.name))"
                    }
                    if !set.prescription.matches(completed.result) {
                        detail += " (planned \(set.prescription.summaryText))"
                    }
                    if let effort = completed.effort {
                        detail += " · \(effort.summaryText)"
                    }
                    if let notes = completed.notes {
                        detail += " · \(notes)"
                    }
                    lines.append(detail)
                } else if skippedSetIDs.contains(set.id) {
                    lines.append("\(index + 1). Skipped (planned \(set.prescription.summaryText))")
                } else {
                    let movement = exerciseDefinition(for: set.id)?.name ?? exerciseName
                    let replacement = movement == exerciseName ? "" : " · \(movement)"
                    lines.append("\(index + 1). Not completed (planned \(set.prescription.summaryText))\(replacement)")
                }
            }
        }

        if let notes = summary.notes {
            lines.append("")
            lines.append("Workout notes: \(notes)")
        }
        return lines.joined(separator: "\n")
    }
}

private extension RepTarget {
    func contains(_ completedReps: CompletedReps) -> Bool {
        switch self {
        case let .exact(reps):
            reps == completedReps.value
        case let .range(lower, upper):
            (lower ... upper).contains(completedReps.value)
        }
    }
}

extension SetPrescription {
    func matches(_ result: SetResult) -> Bool {
        switch (self, result) {
        case let (.weighted(targetReps, targetLoad), .weighted(actualReps, actualLoad)):
            targetReps.contains(actualReps) && targetLoad == actualLoad
        case let (.bodyweight(targetReps), .bodyweight(actualReps)):
            targetReps.contains(actualReps)
        case let (
            .assistedBodyweight(targetReps, targetAssistance),
            .assistedBodyweight(actualReps, actualAssistance)
        ):
            targetReps.contains(actualReps) && targetAssistance == actualAssistance
        case let (.amrap(targetLoad), .amrap(_, actualLoad)):
            targetLoad == actualLoad
        case let (.timed(targetDuration, targetLoad), .timed(actualDuration, actualLoad)):
            targetDuration == actualDuration && targetLoad == actualLoad
        case let (.distance(targetDistance, targetDuration), .distance(actualDistance, actualDuration)):
            targetDistance == actualDistance && (targetDuration == nil || targetDuration == actualDuration)
        default:
            false
        }
    }
}

private extension SetResult {
    var volume: Load? {
        recordedLoadVolume
    }
}

extension SetPrescription {
    var summaryText: String {
        switch self {
        case let .weighted(reps, load):
            "\(load.amount.plainText) \(load.unit.rawValue) × \(reps.summaryText)"
        case let .bodyweight(reps):
            "Bodyweight × \(reps.summaryText)"
        case let .assistedBodyweight(reps, assistance):
            "−\(assistance.amount.plainText) \(assistance.unit.rawValue) assistance × \(reps.summaryText)"
        case let .amrap(load):
            load.map { "\($0.amount.plainText) \($0.unit.rawValue) · AMRAP" } ?? "AMRAP"
        case let .timed(duration, load):
            load.map { "\(duration.seconds) sec · \($0.amount.plainText) \($0.unit.rawValue)" }
                ?? "\(duration.seconds) sec"
        case let .distance(distance, duration):
            duration.map { "\(distance.amount.plainText) \(distance.unit.rawValue) · \($0.seconds) sec" }
                ?? "\(distance.amount.plainText) \(distance.unit.rawValue)"
        }
    }
}

extension SetResult {
    var summaryText: String {
        switch self {
        case let .weighted(reps, load):
            "\(load.amount.plainText) \(load.unit.rawValue) × \(reps.value)"
        case let .bodyweight(reps):
            "Bodyweight × \(reps.value)"
        case let .assistedBodyweight(reps, assistance):
            "−\(assistance.amount.plainText) \(assistance.unit.rawValue) assistance × \(reps.value)"
        case let .amrap(reps, load):
            load.map { "\($0.amount.plainText) \($0.unit.rawValue) × \(reps.value)" }
                ?? "\(reps.value) reps"
        case let .timed(duration, load):
            load.map { "\(duration.seconds) sec · \($0.amount.plainText) \($0.unit.rawValue)" }
                ?? "\(duration.seconds) sec"
        case let .distance(distance, duration):
            duration.map { "\(distance.amount.plainText) \(distance.unit.rawValue) · \($0.seconds) sec" }
                ?? "\(distance.amount.plainText) \(distance.unit.rawValue)"
        }
    }
}

private extension RepTarget {
    var summaryText: String {
        switch self {
        case let .exact(value): "\(value)"
        case let .range(lower, upper): "\(lower)–\(upper)"
        }
    }
}

private extension EffortTarget {
    var summaryText: String {
        switch self {
        case let .rpe(value): "RPE \(value.value.plainText)"
        case let .rir(value): "\(value.value) RIR"
        }
    }
}

private extension Decimal {
    var plainText: String { NSDecimalNumber(decimal: self).stringValue }
}

private extension TimeInterval {
    var clockText: String {
        let seconds = max(0, Int(self.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
