import Foundation

enum WorkoutImportInputMode: String, Codable, Sendable { case json, text }

struct WorkoutImportResponse: Codable, Sendable {
    var schemaVersion: Int
    var classification: String
    var workouts: [ImportedWorkout]
    var issues: [WorkoutImportIssue]
    var confidence: [WorkoutImportConfidence]
    var source: WorkoutImportSource?
}

struct WorkoutImportSource: Codable, Sendable {
    var kind: String
    var originalText: String
    var sourceURL: String?
}

struct WorkoutImportIssue: Codable, Identifiable, Sendable {
    var id: UUID
    var path: String
    var code: String
    var message: String
    var blocking: Bool
    var sourceQuote: String?
}

struct WorkoutImportConfidence: Codable, Sendable {
    var path: String
    var level: String
    var sourceQuote: String?
}

struct ImportedWorkout: Codable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var notes: String?
    var exercises: [ImportedExercise]
}

struct ImportedExercise: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var equipment: String?
    var notes: String?
    var group: ImportedGroup?
    var sets: [ImportedSet]
}

struct ImportedGroup: Codable, Sendable {
    var id: UUID
    var kind: String
    var position: Int
}

struct ImportedSet: Codable, Identifiable, Sendable {
    var id: UUID
    var kind: String
    var role: String
    var side: String
    var reps: ImportedReps?
    var load: ImportedLoad?
    var durationSeconds: Int?
    var distance: ImportedDistance?
    var effort: ImportedEffort?
    var tempo: ImportedTempo?
    var restSeconds: Int?

    func plannedSet() throws -> PlannedSet {
        let permitted: Set<String>
        switch kind {
        case "weighted", "assistedBodyweight": permitted = ["reps", "load"]
        case "bodyweight": permitted = ["reps"]
        case "amrap": permitted = ["load"]
        case "timed": permitted = ["durationSeconds", "load"]
        case "distance": permitted = ["distance", "durationSeconds"]
        default: permitted = []
        }
        let supplied = [("reps", reps != nil), ("load", load != nil), ("durationSeconds", durationSeconds != nil), ("distance", distance != nil)]
        guard supplied.allSatisfy({ !$0.1 || permitted.contains($0.0) }) else {
            throw WorkoutImportError.invalid("This set contains a target incompatible with its type. Edit the set or correct the source JSON; no targets will be silently dropped.")
        }
        guard let role = SetRole(rawValue: role), let side = ExerciseSide(rawValue: side) else {
            throw WorkoutImportError.invalid("Choose a valid set role and side.")
        }
        let prescription: SetPrescription
        switch kind {
        case "weighted": prescription = .weighted(reps: try requiredReps(), load: try requiredLoad())
        case "bodyweight": prescription = .bodyweight(reps: try requiredReps())
        case "assistedBodyweight": prescription = .assistedBodyweight(reps: try requiredReps(), assistance: try requiredLoad())
        case "amrap": prescription = .amrap(load: try load.map { try $0.value() })
        case "timed":
            guard let durationSeconds else { throw WorkoutImportError.invalid("Enter the duration in seconds.") }
            prescription = .timed(duration: try ExerciseDuration(seconds: durationSeconds), load: try load.map { try $0.value() })
        case "distance":
            guard let distance, let unit = distance.unit.flatMap(DistanceUnit.init(rawValue:)) else {
                throw WorkoutImportError.invalid("Enter the distance and choose its unit.")
            }
            prescription = .distance(distance: try ExerciseDistance(amount: distance.amount, unit: unit), durationTarget: try durationSeconds.map { try ExerciseDuration(seconds: $0) })
        default: throw WorkoutImportError.invalid("Choose a supported set type.")
        }
        let target: EffortTarget?
        if let effort {
            switch effort.kind {
            case "rpe": target = .rpe(try RPE(effort.value))
            case "rir":
                let number = NSDecimalNumber(decimal: effort.value).doubleValue
                guard number.isFinite, number.rounded() == number, (0...10).contains(number) else {
                    throw WorkoutImportError.invalid("RIR must be a whole number from 0 to 10.")
                }
                target = .rir(try RIR(Int(number)))
            default: throw WorkoutImportError.invalid("Choose RPE or RIR.")
            }
        } else { target = nil }
        return PlannedSet(id: id, role: role, prescription: prescription, side: side,
                          effortTarget: target, tempo: try tempo?.value(),
                          restAfter: try restSeconds.map { try RestDuration(seconds: $0) })
    }

    private func requiredReps() throws -> RepTarget {
        guard let reps else { throw WorkoutImportError.invalid("Enter the rep target.") }
        return try reps.min == reps.max ? RepTarget(exact: reps.min) : RepTarget(lower: reps.min, upper: reps.max)
    }
    private func requiredLoad() throws -> Load {
        guard let load else { throw WorkoutImportError.invalid("Enter the weight or assistance and choose its unit.") }
        return try load.value()
    }
}

struct ImportedReps: Codable, Sendable { var min: Int; var max: Int }
struct ImportedLoad: Codable, Sendable {
    var amount: Decimal
    var unit: String?
    func value() throws -> Load {
        guard let unit = unit.flatMap(MassUnit.init(rawValue:)) else { throw WorkoutImportError.invalid("Choose kg or lb; the source did not specify a usable weight unit.") }
        return try Load(amount: amount, unit: unit)
    }
}
struct ImportedDistance: Codable, Sendable { var amount: Decimal; var unit: String? }
struct ImportedEffort: Codable, Sendable { var kind: String; var value: Decimal }
struct ImportedTempoPhase: Codable, Sendable {
    var kind: String
    var seconds: Decimal?
    func value() throws -> TempoPhase {
        if kind == "explosive" {
            guard seconds == nil else { throw WorkoutImportError.invalid("Explosive tempo phases must not also specify seconds.") }
            return .explosive
        }
        guard kind == "controlled", let seconds else { throw WorkoutImportError.invalid("Check each tempo phase.") }
        return try TempoPhase(seconds: seconds)
    }
}
struct ImportedTempo: Codable, Sendable {
    var eccentric: ImportedTempoPhase
    var bottomPause: ImportedTempoPhase
    var concentric: ImportedTempoPhase
    var topPause: ImportedTempoPhase
    func value() throws -> Tempo {
        try Tempo(eccentric: eccentric.value(), bottomPause: bottomPause.value(), concentric: concentric.value(), topPause: topPause.value())
    }
}

enum WorkoutImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

struct WorkoutImportDraft: Codable, Sendable {
    var id = UUID()
    var originalText = ""
    var sourceKind: ImportSourceKind = .paste
    var inputMode: WorkoutImportInputMode?
    var sourceURL: URL?
    var sharedPayloadID: UUID?
    var response: WorkoutImportResponse?
    var selectedWorkoutID: UUID?
    var resolvedIssueIDs: Set<String> = []
    var exerciseMappings: [UUID: ExerciseDefinition] = [:]
    var manuallyNamedTitles: [UUID: String]?

    var selectedIndex: Int? { response?.workouts.firstIndex(where: { $0.id == selectedWorkoutID }) }

    func title(for workout: ImportedWorkout) -> String {
        manuallyNamedTitles?[workout.id]?.nilIfBlank
            ?? ImportedWorkoutFocus.title(for: workout.exercises, mappings: exerciseMappings)
    }

    mutating func setTitle(_ title: String, for workout: ImportedWorkout) {
        var titles = manuallyNamedTitles ?? [:]
        titles[workout.id] = title.nilIfBlank
        manuallyNamedTitles = titles.isEmpty ? nil : titles
    }

    func relevantIssues() -> [WorkoutImportIssue] {
        guard let response, let index = selectedIndex else { return [] }
        let prefix = "/workouts/\(index)"
        return response.issues.filter { !$0.path.hasPrefix("/workouts/") || $0.path == prefix || $0.path.hasPrefix(prefix + "/") }
    }

    func definition(for exercise: ImportedExercise) -> ExerciseDefinition? {
        if let mapped = exerciseMappings[exercise.id] { return mapped }
        let matches = ExerciseCatalog.candidates(named: exercise.name).filter {
            exercise.equipment == nil || Self.equipmentMatches(exercise.equipment!, $0.equipment)
        }
        return matches.count == 1 ? matches[0].definition : nil
    }

    mutating func keepUnmatchedNamesAsCustom() throws {
        guard let response, let index = selectedIndex else { return }
        for exercise in response.workouts[index].exercises where definition(for: exercise) == nil {
            exerciseMappings[exercise.id] = try ExerciseDefinition(name: exercise.name, equipment: exercise.equipment)
        }
    }

    func makePlan(requireResolved: Bool = true) throws -> WorkoutPlan {
        guard let response, response.schemaVersion == 1,
              ["single", "multiple"].contains(response.classification), let index = selectedIndex else {
            throw WorkoutImportError.invalid("Choose a workout to review.")
        }
        if requireResolved {
            guard relevantIssues().filter(\.blocking).isEmpty else {
                throw WorkoutImportError.invalid("This file still has unresolved source details. Ask your coach for one definite corrected JSON file before adding it.")
            }
            let prefix = "/workouts/\(index)"
            guard response.confidence.filter({ $0.level != "high" && (!$0.path.hasPrefix("/workouts/") || $0.path == prefix || $0.path.hasPrefix(prefix + "/")) })
                .isEmpty else {
                throw WorkoutImportError.invalid("This file contains uncertain interpretations. Ask your coach for explicit, confirmed values.")
            }
        }
        let workout = response.workouts[index]
        guard workout.exercises.count <= 100, workout.exercises.flatMap(\.sets).count <= 500 else {
            throw WorkoutImportError.invalid("This workout is too large to import as one session.")
        }
        let sets = workout.exercises.flatMap(\.sets)
        let itemIDs = [workout.id] + workout.exercises.map(\.id) + sets.map(\.id)
        guard Set(itemIDs).count == itemIDs.count else {
            throw WorkoutImportError.invalid("The import contains duplicate item identifiers. Retry parsing.")
        }
        let members = Dictionary(grouping: workout.exercises.enumerated().filter { $0.element.group != nil }, by: { $0.element.group!.id })
        for group in members.values {
            let positions = group.map { $0.element.group!.position }
            let kinds = Set(group.map { $0.element.group!.kind })
            let adjacent = zip(group, group.dropFirst()).allSatisfy { $1.offset == $0.offset + 1 }
            guard group.count >= 2, kinds.count == 1, positions == Array(0..<group.count), adjacent else {
                throw WorkoutImportError.invalid("Groups need adjacent exercises, one kind, and consecutive positions starting at zero. Correct the source JSON.")
            }
        }
        let exercises = try workout.exercises.map { exercise in
            guard exercise.name.range(of: #"\b(?:or|and/or)\b"#, options: [.regularExpression, .caseInsensitive]) == nil else {
                throw WorkoutImportError.invalid("Choose one definite exercise instead of alternatives in the source JSON.")
            }
            guard let definition = definition(for: exercise) else {
                throw WorkoutImportError.invalid("Match \(exercise.name) to the library or explicitly keep it as a custom exercise.")
            }
            let group: ExerciseGroup?
            if let imported = exercise.group {
                guard let kind = ExerciseGroupKind(rawValue: imported.kind) else { throw WorkoutImportError.invalid("Check the exercise grouping.") }
                group = try ExerciseGroup(id: imported.id, kind: kind, position: imported.position)
            } else { group = nil }
            return try PlannedExercise(id: exercise.id, exercise: definition, sets: exercise.sets.map { try $0.plannedSet() }, group: group, notes: exercise.notes)
        }
        return try WorkoutPlan(id: workout.id, title: title(for: workout), exercises: exercises, notes: workout.notes,
                               importSource: ImportSource(kind: sourceKind, originalText: originalText, sourceURL: sourceURL))
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func equipmentMatches(_ imported: String, _ catalog: String) -> Bool {
        let source = ExerciseCatalog.normalizedName(imported)
        let target = ExerciseCatalog.normalizedName(catalog)
        if source == target { return true }
        if target == "unspecified" || target == "other" { return true }
        let kinds = ["barbell", "dumbbell", "cable", "bodyweight", "kettlebell", "smith", "band", "ez bar", "trap bar"]
        let sourceKinds = Set(kinds.filter { source.contains($0) })
        let targetKinds = Set(kinds.filter { target.contains($0) })
        if !sourceKinds.isEmpty || !targetKinds.isEmpty {
            if !sourceKinds.isDisjoint(with: targetKinds) { return true }
            return target.contains(" or ") && source.contains("machine") && target.contains("machine")
        }
        return source.contains("machine") && target.contains("machine")
    }
}

enum ImportedWorkoutFocus {
    private enum Region { case upper, lower, fullBody, neutral, unknown }

    static func title(for exercises: [ImportedExercise], mappings: [UUID: ExerciseDefinition]) -> String {
        let regions = exercises.map { region(for: $0, mapped: mappings[$0.id]) }
        let upper = regions.contains { $0 == .upper || $0 == .fullBody }
        let lower = regions.contains { $0 == .lower || $0 == .fullBody }
        if upper && lower { return "Full Body" }
        if regions.contains(where: { $0 == .unknown }) { return "Workout" }
        if upper { return "Upper Body" }
        if lower { return "Lower Body" }
        return "Workout"
    }

    private static func region(for exercise: ImportedExercise, mapped: ExerciseDefinition?) -> Region {
        let name = normalized(mapped?.name ?? exercise.name)
        let catalog: CatalogExercise?
        if let mapped {
            catalog = ExerciseCatalog.exercises.first { mapped.id == $0.definition.id }
        } else {
            let candidates = ExerciseCatalog.candidates(named: name)
            catalog = candidates.count == 1 ? candidates[0] : nil
        }
        if let catalog {
            switch catalog.category {
            case .legs: return .lower
            case .chest, .back, .shoulders, .arms: return .upper
            case .core, .cardio, .mobility, .other: return .neutral
            case .fullBody: return .fullBody
            }
        }
        if hasTerm(name, in: ["rowing machine", "rower", "ergometer", "bike", "cycle", "treadmill", "elliptical", "crunch", "plank", "twist", "leg raise", "sit-up", "dead bug", "bird dog", "mountain climber", "pallof", "ab wheel", "mobility", "stretch"]) { return .neutral }
        let lower = hasTerm(name, in: ["squat", "deadlift", "lunge", "leg press", "leg curl", "leg extension", "calf", "hamstring", "quad", "glute", "hip", "adductor", "abductor", "step-up", "step up", "rock-back"])
        let upper = hasTerm(name, in: ["bench press", "chest", "push-up", "pull-up", "pulldown", "row", "curl", "triceps", "biceps", "shoulder", "lat", "pec", "fly", "dip", "face pull", "overhead press"])
        if lower && hasTerm(name, in: ["leg curl", "hamstring curl"]) { return .lower }
        if upper && lower { return .unknown }
        if upper { return .upper }
        if lower { return .lower }
        if hasTerm(name, in: ["warm-up", "warmup"]) || ["walk", "walking", "run", "running"].contains(name) { return .neutral }
        return .unknown
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func hasTerm(_ name: String, in terms: [String]) -> Bool {
        terms.contains { name.contains($0) }
    }
}
