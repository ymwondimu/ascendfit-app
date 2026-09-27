import Foundation

enum MassUnit: String, Codable, CaseIterable, Sendable {
    case kilograms = "kg"
    case pounds = "lb"
}

struct Load: Codable, Equatable, Sendable {
    let amount: Decimal
    let unit: MassUnit

    init(amount: Decimal, unit: MassUnit) throws {
        guard amount >= 0 else {
            throw DomainValidationError.outOfRange(field: "load.amount")
        }

        self.amount = amount
        self.unit = unit
    }
}

enum RepTarget: Codable, Equatable, Sendable {
    case exact(Int)
    case range(lower: Int, upper: Int)

    init(exact: Int) throws {
        guard exact > 0 else {
            throw DomainValidationError.outOfRange(field: "reps")
        }

        self = .exact(exact)
    }

    init(lower: Int, upper: Int) throws {
        guard lower > 0, upper > 0 else {
            throw DomainValidationError.outOfRange(field: "reps")
        }
        guard lower <= upper else {
            throw DomainValidationError.invalidRange(field: "reps")
        }

        self = .range(lower: lower, upper: upper)
    }
}

struct CompletedReps: Codable, Equatable, Sendable {
    let value: Int

    init(_ value: Int) throws {
        guard value > 0 else {
            throw DomainValidationError.outOfRange(field: "completedReps")
        }

        self.value = value
    }
}

struct ExerciseDuration: Codable, Equatable, Sendable {
    let seconds: Int

    init(seconds: Int) throws {
        guard seconds > 0 else {
            throw DomainValidationError.outOfRange(field: "duration.seconds")
        }

        self.seconds = seconds
    }
}

enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case meters = "m"
    case kilometers = "km"
    case miles = "mi"
}

struct ExerciseDistance: Codable, Equatable, Sendable {
    let amount: Decimal
    let unit: DistanceUnit

    init(amount: Decimal, unit: DistanceUnit) throws {
        guard amount > 0 else {
            throw DomainValidationError.outOfRange(field: "distance.amount")
        }

        self.amount = amount
        self.unit = unit
    }
}

struct RPE: Codable, Equatable, Sendable {
    let value: Decimal

    init(_ value: Decimal) throws {
        guard (0 ... 10).contains(value) else {
            throw DomainValidationError.outOfRange(field: "rpe")
        }

        self.value = value
    }
}

struct RIR: Codable, Equatable, Sendable {
    let value: Int

    init(_ value: Int) throws {
        guard (0 ... 10).contains(value) else {
            throw DomainValidationError.outOfRange(field: "rir")
        }

        self.value = value
    }
}

enum EffortTarget: Codable, Equatable, Sendable {
    case rpe(RPE)
    case rir(RIR)
}

enum TempoPhase: Codable, Equatable, Sendable {
    case controlled(seconds: Decimal)
    case explosive

    init(seconds: Decimal) throws {
        guard seconds >= 0 else {
            throw DomainValidationError.outOfRange(field: "tempo")
        }

        self = .controlled(seconds: seconds)
    }
}

struct Tempo: Codable, Equatable, Sendable {
    let eccentric: TempoPhase
    let bottomPause: TempoPhase
    let concentric: TempoPhase
    let topPause: TempoPhase
}

struct RestDuration: Codable, Equatable, Sendable {
    let seconds: Int

    init(seconds: Int) throws {
        guard seconds >= 0 else {
            throw DomainValidationError.outOfRange(field: "rest.seconds")
        }

        self.seconds = seconds
    }
}

enum ExerciseSide: String, Codable, CaseIterable, Sendable {
    case bilateral
    case left
    case right
    case alternating
    case perSide
}
