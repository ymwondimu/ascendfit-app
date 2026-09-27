import Foundation

enum SetResult: Codable, Equatable, Sendable {
    case weighted(reps: CompletedReps, load: Load)
    case bodyweight(reps: CompletedReps)
    case assistedBodyweight(reps: CompletedReps, assistance: Load)
    case amrap(reps: CompletedReps, load: Load?)
    case timed(duration: ExerciseDuration, load: Load?)
    case distance(distance: ExerciseDistance, duration: ExerciseDuration?)
}

struct CompletedSet: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let plannedSetID: UUID
    let result: SetResult
    let effort: EffortTarget?
    let completedAt: Date
    let notes: String?

    init(
        id: UUID = UUID(),
        plannedSetID: UUID,
        result: SetResult,
        effort: EffortTarget? = nil,
        completedAt: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.plannedSetID = plannedSetID
        self.result = result
        self.effort = effort
        self.completedAt = completedAt
        self.notes = notes?.nilIfBlank == nil ? nil : notes
    }
}

enum ResumableSessionStatus: Codable, Equatable, Sendable {
    case active
    case resting(deadline: Date)
}

enum WorkoutSessionStatus: Codable, Equatable, Sendable {
    case notStarted
    case active
    case resting(deadline: Date)
    case paused(resumeStatus: ResumableSessionStatus)
    case completing
    case completed(at: Date)
    case discarded(at: Date)

    var label: String {
        switch self {
        case .notStarted: "notStarted"
        case .active: "active"
        case .resting: "resting"
        case .paused: "paused"
        case .completing: "completing"
        case .completed: "completed"
        case .discarded: "discarded"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .discarded:
            true
        default:
            false
        }
    }
}

enum SessionCommand: Sendable {
    case start
    case selectNextSet(UUID)
    case pause
    case resume
    case completeSet(plannedSetID: UUID, result: SetResult, effort: EffortTarget?, notes: String?)
    case editSet(completedSetID: UUID, result: SetResult, effort: EffortTarget?, notes: String?)
    case adjustRemainingSets(exerciseID: UUID, result: SetResult)
    case skipSet(plannedSetID: UUID)
    case addSet(exerciseID: UUID, set: PlannedSet)
    case replaceExercise(plannedExerciseID: UUID, replacement: ExerciseDefinition)
    case startRest(duration: RestDuration)
    case setExerciseRest(exerciseID: UUID, duration: RestDuration)
    case adjustRest(bySeconds: Int)
    case endRest
    case undoLastSet
    case prepareToFinish
    case finish(notes: String?)
    case discard

    var label: String {
        switch self {
        case .start: "start"
        case .selectNextSet: "selectNextSet"
        case .pause: "pause"
        case .resume: "resume"
        case .completeSet: "completeSet"
        case .editSet: "editSet"
        case .adjustRemainingSets: "adjustRemainingSets"
        case .skipSet: "skipSet"
        case .addSet: "addSet"
        case .replaceExercise: "replaceExercise"
        case .startRest: "startRest"
        case .setExerciseRest: "setExerciseRest"
        case .adjustRest: "adjustRest"
        case .endRest: "endRest"
        case .undoLastSet: "undoLastSet"
        case .prepareToFinish: "prepareToFinish"
        case .finish: "finish"
        case .discard: "discard"
        }
    }
}

struct SessionEvent: Codable, Equatable, Identifiable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        case started
        case nextSetSelected(plannedSetID: UUID)
        case paused
        case resumed
        case setCompleted(CompletedSet)
        case setEdited(CompletedSet)
        case remainingSetsAdjusted(exerciseID: UUID, plannedSetIDs: [UUID], result: SetResult)
        case setSkipped(plannedSetID: UUID)
        case setAdded(exerciseID: UUID, set: PlannedSet)
        case exerciseReplaced(plannedExerciseID: UUID, replacement: ExerciseDefinition)
        case restStarted(deadline: Date)
        case exerciseRestChanged(exerciseID: UUID, duration: RestDuration)
        case restAdjusted(deadline: Date)
        case restEnded
        case setCompletionUndone(completedSetID: UUID)
        case finishPrepared
        case finished(notes: String?)
        case discarded
    }

    let id: UUID
    let sessionID: UUID
    let occurredAt: Date
    let kind: Kind
}

struct WorkoutSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let plan: WorkoutPlan
    private(set) var selectedNextSetID: UUID?
    private(set) var status: WorkoutSessionStatus
    private(set) var completedSets: [CompletedSet]
    private(set) var setResultOverrides: [UUID: SetResult]
    private(set) var skippedSetIDs: Set<UUID>
    private(set) var addedSets: [UUID: [PlannedSet]]
    private(set) var exerciseReplacements: [UUID: ExerciseDefinition]
    private(set) var completionNotes: String?
    private(set) var events: [SessionEvent]

    init(id: UUID = UUID(), plan: WorkoutPlan) {
        self.id = id
        self.plan = plan
        status = .notStarted
        completedSets = []
        setResultOverrides = [:]
        skippedSetIDs = []
        addedSets = [:]
        exerciseReplacements = [:]
        completionNotes = nil
        events = []
    }

    init(id: UUID, plan: WorkoutPlan, replaying events: [SessionEvent]) throws {
        self.init(id: id, plan: plan)
        for event in events {
            guard event.sessionID == id else {
                throw DomainValidationError.invalidTransition(
                    from: status.label,
                    command: "foreignEvent"
                )
            }
            guard self.events.last.map({ $0.occurredAt <= event.occurredAt }) ?? true else {
                throw DomainValidationError.nonChronologicalEvent
            }
            try apply(event)
            self.events.append(event)
        }
    }

    @discardableResult
    mutating func handle(
        _ command: SessionCommand,
        at date: Date = Date(),
        eventID: UUID = UUID(),
        completedSetID: UUID = UUID()
    ) throws -> SessionEvent {
        guard events.last.map({ $0.occurredAt <= date }) ?? true else {
            throw DomainValidationError.nonChronologicalEvent
        }

        let kind: SessionEvent.Kind

        switch command {
        case .start:
            kind = .started
        case let .selectNextSet(id):
            kind = .nextSetSelected(plannedSetID: id)
        case .pause:
            kind = .paused
        case .resume:
            kind = .resumed
        case let .completeSet(plannedSetID, result, effort, notes):
            kind = .setCompleted(
                CompletedSet(
                    id: completedSetID,
                    plannedSetID: plannedSetID,
                    result: result,
                    effort: effort,
                    completedAt: date,
                    notes: notes
                )
            )
        case let .editSet(completedSetID, result, effort, notes):
            guard let existing = completedSets.first(where: { $0.id == completedSetID }) else {
                throw DomainValidationError.unknownCompletedSet(completedSetID)
            }
            kind = .setEdited(
                CompletedSet(
                    id: existing.id,
                    plannedSetID: existing.plannedSetID,
                    result: result,
                    effort: effort,
                    completedAt: existing.completedAt,
                    notes: notes
                )
            )
        case let .adjustRemainingSets(exerciseID, result):
            guard let exercise = plan.exercises.first(where: { $0.id == exerciseID }) else {
                throw DomainValidationError.unknownPlannedExercise(exerciseID)
            }
            let sets = exercise.sets + addedSets[exerciseID, default: []]
            let plannedSetIDs: [UUID] = sets.compactMap { set -> UUID? in
                guard !completedSets.contains(where: { $0.plannedSetID == set.id }),
                      !skippedSetIDs.contains(set.id),
                      set.prescription.accepts(result)
                else { return nil }
                return set.id
            }
            kind = .remainingSetsAdjusted(
                exerciseID: exerciseID,
                plannedSetIDs: plannedSetIDs,
                result: result
            )
        case let .skipSet(plannedSetID):
            kind = .setSkipped(plannedSetID: plannedSetID)
        case let .addSet(exerciseID, set):
            kind = .setAdded(exerciseID: exerciseID, set: set)
        case let .replaceExercise(plannedExerciseID, replacement):
            kind = .exerciseReplaced(
                plannedExerciseID: plannedExerciseID,
                replacement: replacement
            )
        case let .setExerciseRest(exerciseID, duration):
            kind = .exerciseRestChanged(exerciseID: exerciseID, duration: duration)
        case let .startRest(duration):
            guard duration.seconds > 0 else {
                throw DomainValidationError.outOfRange(field: "rest.seconds")
            }
            kind = .restStarted(
                deadline: date.addingTimeInterval(TimeInterval(duration.seconds))
            )
        case let .adjustRest(seconds):
            guard case let .resting(deadline) = status else {
                throw DomainValidationError.invalidTransition(
                    from: status.label,
                    command: command.label
                )
            }
            let adjustedDeadline = deadline.addingTimeInterval(TimeInterval(seconds))
            kind = adjustedDeadline > date
                ? .restAdjusted(deadline: adjustedDeadline)
                : .restEnded
        case .endRest:
            kind = .restEnded
        case .undoLastSet:
            guard let completedSetID = completedSets.last?.id else {
                throw DomainValidationError.nothingToUndo
            }
            kind = .setCompletionUndone(completedSetID: completedSetID)
        case .prepareToFinish:
            kind = .finishPrepared
        case let .finish(notes):
            kind = .finished(notes: notes?.nilIfBlank == nil ? nil : notes)
        case .discard:
            kind = .discarded
        }

        let event = SessionEvent(
            id: eventID,
            sessionID: id,
            occurredAt: date,
            kind: kind
        )
        do {
            try apply(event)
        } catch DomainValidationError.invalidTransition {
            throw DomainValidationError.invalidTransition(from: status.label, command: command.label)
        }
        events.append(event)
        return event
    }

    private mutating func apply(_ event: SessionEvent) throws {
        switch event.kind {
        case .started:
            guard status == .notStarted else { throw invalidEvent("started") }
            status = .active

        case let .nextSetSelected(id):
            guard status == .active else { throw invalidEvent("nextSetSelected") }
            guard plannedSet(id: id) != nil else { throw DomainValidationError.unknownPlannedSet(id) }
            guard !completedSets.contains(where: { $0.plannedSetID == id }) else {
                throw DomainValidationError.alreadyCompleted(id)
            }
            guard !skippedSetIDs.contains(id) else { throw DomainValidationError.alreadySkipped(id) }
            selectedNextSetID = id

        case .paused:
            switch status {
            case .active:
                status = .paused(resumeStatus: .active)
            case let .resting(deadline):
                status = .paused(resumeStatus: .resting(deadline: deadline))
            default:
                throw invalidEvent("paused")
            }

        case .resumed:
            guard case let .paused(resumeStatus) = status else {
                throw invalidEvent("resumed")
            }
            switch resumeStatus {
            case .active:
                status = .active
            case let .resting(deadline):
                let pausedAt = events.last(where: {
                    if case .paused = $0.kind { return true }
                    return false
                })?.occurredAt ?? event.occurredAt
                let remaining = max(0, deadline.timeIntervalSince(pausedAt))
                status = remaining > 0
                    ? .resting(deadline: event.occurredAt.addingTimeInterval(remaining))
                    : .active
            }

        case let .setCompleted(completedSet):
            guard status == .active else { throw invalidEvent("setCompleted") }
            guard let plannedSet = plannedSet(id: completedSet.plannedSetID) else {
                throw DomainValidationError.unknownPlannedSet(completedSet.plannedSetID)
            }
            guard !completedSets.contains(where: { $0.plannedSetID == completedSet.plannedSetID }) else {
                throw DomainValidationError.alreadyCompleted(completedSet.plannedSetID)
            }
            guard !skippedSetIDs.contains(completedSet.plannedSetID) else {
                throw DomainValidationError.alreadySkipped(completedSet.plannedSetID)
            }

            selectedNextSetID = nil
            completedSets.append(completedSet)
            if hasPendingSet, let seconds = restDuration(for: plannedSet.id)?.seconds, seconds > 0 {
                status = .resting(deadline: event.occurredAt.addingTimeInterval(TimeInterval(seconds)))
            }

        case let .setEdited(completedSet):
            guard status == .active || isResting else { throw invalidEvent("setEdited") }
            guard let index = completedSets.firstIndex(where: { $0.id == completedSet.id }) else {
                throw DomainValidationError.unknownCompletedSet(completedSet.id)
            }
            completedSets[index] = completedSet

        case let .remainingSetsAdjusted(exerciseID, plannedSetIDs, result):
            guard status == .active else { throw invalidEvent("remainingSetsAdjusted") }
            guard let exercise = plan.exercises.first(where: { $0.id == exerciseID }) else {
                throw DomainValidationError.unknownPlannedExercise(exerciseID)
            }
            let validIDs = Set((exercise.sets + addedSets[exerciseID, default: []]).map(\.id))
            for plannedSetID in plannedSetIDs {
                guard validIDs.contains(plannedSetID) else {
                    throw DomainValidationError.unknownPlannedSet(plannedSetID)
                }
                guard !completedSets.contains(where: { $0.plannedSetID == plannedSetID }),
                      !skippedSetIDs.contains(plannedSetID)
                else { throw invalidEvent("remainingSetsAdjusted") }
                setResultOverrides[plannedSetID] = result
            }

        case let .setSkipped(plannedSetID):
            guard status == .active else { throw invalidEvent("setSkipped") }
            guard plannedSet(id: plannedSetID) != nil else {
                throw DomainValidationError.unknownPlannedSet(plannedSetID)
            }
            guard !completedSets.contains(where: { $0.plannedSetID == plannedSetID }) else {
                throw DomainValidationError.alreadyCompleted(plannedSetID)
            }
            guard skippedSetIDs.insert(plannedSetID).inserted else {
                throw DomainValidationError.alreadySkipped(plannedSetID)
            }

            if selectedNextSetID == plannedSetID { selectedNextSetID = nil }

        case let .setAdded(exerciseID, set):
            guard status == .active else { throw invalidEvent("setAdded") }
            guard plan.exercises.contains(where: { $0.id == exerciseID }) else {
                throw DomainValidationError.unknownPlannedExercise(exerciseID)
            }
            addedSets[exerciseID, default: []].append(set)

        case let .exerciseReplaced(plannedExerciseID, replacement):
            guard status == .active else { throw invalidEvent("exerciseReplaced") }
            guard plan.exercises.contains(where: { $0.id == plannedExerciseID }) else {
                throw DomainValidationError.unknownPlannedExercise(plannedExerciseID)
            }
            exerciseReplacements[plannedExerciseID] = replacement

        case let .exerciseRestChanged(exerciseID, _):
            guard status == .active || isResting else { throw invalidEvent("exerciseRestChanged") }
            guard plan.exercises.contains(where: { $0.id == exerciseID }) else {
                throw DomainValidationError.unknownPlannedExercise(exerciseID)
            }

        case let .restStarted(deadline):
            guard status == .active else { throw invalidEvent("restStarted") }
            guard deadline > event.occurredAt else {
                throw DomainValidationError.outOfRange(field: "rest.deadline")
            }
            status = .resting(deadline: deadline)

        case let .restAdjusted(deadline):
            guard case .resting = status else { throw invalidEvent("restAdjusted") }
            guard deadline > event.occurredAt else {
                throw DomainValidationError.outOfRange(field: "rest.deadline")
            }
            status = .resting(deadline: deadline)

        case .restEnded:
            guard case .resting = status else { throw invalidEvent("restEnded") }
            status = .active

        case let .setCompletionUndone(completedSetID):
            guard status == .active || isResting else {
                throw invalidEvent("setCompletionUndone")
            }
            guard completedSets.last?.id == completedSetID else {
                throw DomainValidationError.nothingToUndo
            }
            selectedNextSetID = nil
            completedSets.removeLast()
            status = .active

        case .finishPrepared:
            switch status {
            case .active, .resting, .paused:
                status = .completing
            default:
                throw invalidEvent("finishPrepared")
            }

        case let .finished(notes):
            switch status {
            case .active, .resting, .paused, .completing:
                break
            default:
                throw invalidEvent("finished")
            }
            completionNotes = notes
            status = .completed(at: event.occurredAt)

        case .discarded:
            switch status {
            case .completed, .discarded:
                throw invalidEvent("discarded")
            default:
                status = .discarded(at: event.occurredAt)
            }
        }
    }

    private var isResting: Bool {
        if case .resting = status { return true }
        return false
    }

    private func plannedSet(id: UUID) -> PlannedSet? {
        let planned = plan.exercises.lazy.flatMap(\.sets).first(where: { $0.id == id })
        return planned ?? addedSets.values.lazy.flatMap { $0 }.first(where: { $0.id == id })
    }

    private var hasPendingSet: Bool {
        let allSets = plan.exercises.flatMap(\.sets) + addedSets.values.flatMap { $0 }
        return allSets.contains { set in
            !completedSets.contains(where: { $0.plannedSetID == set.id })
                && !skippedSetIDs.contains(set.id)
        }
    }

    var nextPendingSetID: UUID? {
        let pending = executionOrder.filter { item in
            !skippedSetIDs.contains(item.set.id) && !completedSets.contains { $0.plannedSetID == item.set.id }
        }
        if let selectedNextSetID, pending.contains(where: { $0.set.id == selectedNextSetID }) {
            return selectedNextSetID
        }
        return pending.first?.set.id
    }

    /// Groups run one set of each movement per round; unequal set counts and added
    /// sets continue in subsequent rounds without manufacturing placeholder sets.
    var executionOrder: [(exercise: PlannedExercise, set: PlannedSet)] {
        var order: [(exercise: PlannedExercise, set: PlannedSet)] = []
        var visitedGroups: Set<UUID> = []
        for exercise in plan.exercises {
            guard let group = exercise.group else {
                order += (exercise.sets + addedSets[exercise.id, default: []]).map { (exercise, $0) }
                continue
            }
            guard visitedGroups.insert(group.id).inserted else { continue }
            let members = plan.exercises.enumerated()
                .filter { $0.element.group?.id == group.id }
                .sorted {
                    let lhs = $0.element.group?.position ?? 0
                    let rhs = $1.element.group?.position ?? 0
                    return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
                }.map(\.element)
            let rounds = members.map { $0.sets.count + addedSets[$0.id, default: []].count }.max() ?? 0
            for round in 0..<rounds {
                for member in members {
                    let sets = member.sets + addedSets[member.id, default: []]
                    if sets.indices.contains(round) { order.append((member, sets[round])) }
                }
            }
        }
        return order
    }

    /// Resolves the movement at the current result's completion event, rather than
    /// relabeling older work when a remaining exercise is replaced.
    func exerciseDefinition(for setID: UUID) -> ExerciseDefinition? {
        guard let exercise = plan.exercises.first(where: {
            ($0.sets + addedSets[$0.id, default: []]).contains(where: { $0.id == setID })
        }) else { return nil }
        guard let completed = completedSets.first(where: { $0.plannedSetID == setID }) else {
            return exerciseReplacements[exercise.id] ?? exercise.exercise
        }
        var definition = exercise.exercise
        for event in events {
            switch event.kind {
            case let .exerciseReplaced(id, replacement) where id == exercise.id:
                definition = replacement
            case let .setCompleted(result) where result.id == completed.id:
                return definition
            default: break
            }
        }
        return definition
    }

    /// A skipped set still occupies its original round in a grouped workout.
    func groupRound(for setID: UUID) -> Int? {
        guard let exercise = plan.exercises.first(where: {
            $0.group != nil && ($0.sets + addedSets[$0.id, default: []]).contains(where: { $0.id == setID })
        }) else { return nil }
        return (exercise.sets + addedSets[exercise.id, default: []])
            .firstIndex(where: { $0.id == setID }).map { $0 + 1 }
    }

    func setDefinition(id: UUID) -> PlannedSet? {
        plannedSet(id: id)
    }

    func restDuration(for setID: UUID) -> RestDuration? {
        guard let exercise = plan.exercises.first(where: {
            ($0.sets + addedSets[$0.id, default: []]).contains(where: { $0.id == setID })
        }) else { return nil }
        for event in events.reversed() {
            if case let .exerciseRestChanged(exerciseID, duration) = event.kind,
               exerciseID == exercise.id { return duration }
        }
        return setDefinition(id: setID)?.restAfter
    }

    func resultOverride(for plannedSetID: UUID) -> SetResult? {
        setResultOverrides[plannedSetID]
    }

    private func invalidEvent(_ event: String) -> DomainValidationError {
        .invalidTransition(from: status.label, command: event)
    }
}

extension SetPrescription {
    func accepts(_ result: SetResult) -> Bool {
        switch (self, result) {
        case (.weighted, .weighted),
             (.bodyweight, .bodyweight),
             (.assistedBodyweight, .assistedBodyweight),
             (.amrap, .amrap),
             (.timed, .timed),
             (.distance, .distance):
            true
        default:
            false
        }
    }
}
