import Foundation

struct ExerciseDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let aliases: Set<String>
    let description: String?
    let equipment: String?
    let primaryMuscles: [String]?

    init(
        id: UUID = UUID(),
        name: String,
        aliases: Set<String> = [],
        description: String? = nil,
        equipment: String? = nil,
        primaryMuscles: [String]? = nil
    ) throws {
        guard let name = name.nilIfBlank else {
            throw DomainValidationError.empty(field: "exercise.name")
        }

        self.id = id
        self.name = name
        self.aliases = Set(aliases.compactMap(\.nilIfBlank))
        self.description = description?.nilIfBlank
        self.equipment = equipment?.nilIfBlank
        self.primaryMuscles = primaryMuscles
    }
}

enum SetRole: String, Codable, Sendable {
    case warmUp
    case working
    case drop
    case failure
}

enum SetPrescription: Codable, Equatable, Sendable {
    case weighted(reps: RepTarget, load: Load)
    case bodyweight(reps: RepTarget)
    case assistedBodyweight(reps: RepTarget, assistance: Load)
    case amrap(load: Load?)
    case timed(duration: ExerciseDuration, load: Load?)
    case distance(distance: ExerciseDistance, durationTarget: ExerciseDuration?)
}

struct PlannedSet: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let role: SetRole
    let prescription: SetPrescription
    let side: ExerciseSide
    let effortTarget: EffortTarget?
    let tempo: Tempo?
    let restAfter: RestDuration?

    init(
        id: UUID = UUID(),
        role: SetRole = .working,
        prescription: SetPrescription,
        side: ExerciseSide = .bilateral,
        effortTarget: EffortTarget? = nil,
        tempo: Tempo? = nil,
        restAfter: RestDuration? = nil
    ) {
        self.id = id
        self.role = role
        self.prescription = prescription
        self.side = side
        self.effortTarget = effortTarget
        self.tempo = tempo
        self.restAfter = restAfter
    }
}

enum ExerciseGroupKind: String, Codable, Sendable {
    case superset
    case circuit
}

struct ExerciseGroup: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: ExerciseGroupKind
    let position: Int

    init(id: UUID = UUID(), kind: ExerciseGroupKind, position: Int) throws {
        guard position >= 0 else {
            throw DomainValidationError.outOfRange(field: "group.position")
        }

        self.id = id
        self.kind = kind
        self.position = position
    }
}

struct PlannedExercise: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let exercise: ExerciseDefinition
    let sets: [PlannedSet]
    let group: ExerciseGroup?
    let notes: String?

    init(
        id: UUID = UUID(),
        exercise: ExerciseDefinition,
        sets: [PlannedSet],
        group: ExerciseGroup? = nil,
        notes: String? = nil
    ) throws {
        guard !sets.isEmpty else {
            throw DomainValidationError.empty(field: "plannedExercise.sets")
        }

        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.group = group
        self.notes = notes?.nilIfBlank
    }
}

struct WorkoutPlan: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let id: UUID
    let schemaVersion: Int
    let title: String
    let scheduledDate: Date?
    let exercises: [PlannedExercise]
    let notes: String?
    let importSource: ImportSource?

    private enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case title
        case scheduledDate
        case exercises
        case notes
        case importSource
    }

    init(
        id: UUID = UUID(),
        schemaVersion: Int = WorkoutPlan.currentSchemaVersion,
        title: String,
        scheduledDate: Date? = nil,
        exercises: [PlannedExercise],
        notes: String? = nil,
        importSource: ImportSource? = nil
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DomainValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard let title = title.nilIfBlank else {
            throw DomainValidationError.empty(field: "workout.title")
        }
        guard !exercises.isEmpty else {
            throw DomainValidationError.empty(field: "workout.exercises")
        }

        self.id = id
        self.schemaVersion = schemaVersion
        self.title = title
        self.scheduledDate = scheduledDate
        self.exercises = exercises
        self.notes = notes?.nilIfBlank
        self.importSource = importSource
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        let id = try values.decode(UUID.self, forKey: .id)
        let title = try values.decode(String.self, forKey: .title)
        let scheduledDate = try values.decodeIfPresent(Date.self, forKey: .scheduledDate)
        let exercises = try values.decode([PlannedExercise].self, forKey: .exercises)
        let notes = try values.decodeIfPresent(String.self, forKey: .notes)
        let importSource = try values.decodeIfPresent(ImportSource.self, forKey: .importSource)

        do {
            try self.init(
                id: id,
                schemaVersion: schemaVersion,
                title: title,
                scheduledDate: scheduledDate,
                exercises: exercises,
                notes: notes,
                importSource: importSource
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: values,
                debugDescription: "Unsupported or invalid WorkoutPlan schema version: \(schemaVersion)"
            )
        }
    }
}

enum ImportSourceKind: String, Codable, Sendable {
    case paste
    case shareSheet
    case manual
    case workoutPlanFile
    case universalLink
}

struct ImportSource: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: ImportSourceKind
    let originalText: String?
    let sourceURL: URL?

    init(
        id: UUID = UUID(),
        kind: ImportSourceKind,
        originalText: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.originalText = originalText?.nilIfBlank == nil ? nil : originalText
        self.sourceURL = sourceURL
    }
}

struct UnresolvedField: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let path: String
    let reason: String

    init(id: UUID = UUID(), path: String, reason: String) throws {
        guard let path = path.nilIfBlank else {
            throw DomainValidationError.empty(field: "unresolved.path")
        }
        guard let reason = reason.nilIfBlank else {
            throw DomainValidationError.empty(field: "unresolved.reason")
        }

        self.id = id
        self.path = path
        self.reason = reason
    }
}

struct WorkoutDraft: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let source: ImportSource
    let plan: WorkoutPlan?
    let unresolvedFields: [UnresolvedField]

    var isReadyToSchedule: Bool {
        plan != nil && unresolvedFields.isEmpty
    }
}
