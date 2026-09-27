import Foundation

enum TrainingSex: String, CaseIterable, Identifiable, Sendable {
    case female = "Female"
    case male = "Male"
    case preferNotToSay = "Prefer not to say"

    var id: String { rawValue }
}

enum TrainingExperience: String, CaseIterable, Identifiable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var loadMultiplier: Double {
        switch self {
        case .beginner: 0.8
        case .intermediate: 1.1
        case .advanced: 1.4
        }
    }
}

struct TrainingProfile: Equatable, Sendable {
    let sex: TrainingSex
    let heightCentimeters: Double
    let bodyWeightKilograms: Double
    let experience: TrainingExperience

    init(
        sex: TrainingSex = .preferNotToSay,
        heightCentimeters: Double,
        bodyWeightKilograms: Double,
        experience: TrainingExperience
    ) {
        self.sex = sex
        self.heightCentimeters = heightCentimeters
        self.bodyWeightKilograms = bodyWeightKilograms
        self.experience = experience
    }
}

enum StartingLoadSuggestion {
    static func amount(
        for exercise: CatalogExercise,
        profile: TrainingProfile,
        unit: MassUnit
    ) -> Double? {
        guard case .weighted = exercise.modality else { return nil }
        guard profile.heightCentimeters > 0, profile.bodyWeightKilograms > 0 else { return nil }

        let heightMeters = profile.heightCentimeters / 100
        let bodyMassIndex = profile.bodyWeightKilograms / (heightMeters * heightMeters)

        // Body weight is only a rough starting signal. For higher BMI values, reduce
        // its influence so the estimate does not scale aggressively with total mass.
        let bodySizeAdjustment = min(1, sqrt(27 / max(bodyMassIndex, 27)))
        let effectiveBodyWeight = profile.bodyWeightKilograms * bodySizeAdjustment
        let kilograms = effectiveBodyWeight * loadFactor(for: exercise) * profile.experience.loadMultiplier

        switch unit {
        case .kilograms:
            return rounded(kilograms, increment: 2.5)
        case .pounds:
            return rounded(kilograms * 2.204_622_621_8, increment: 5)
        }
    }

    private static func rounded(_ value: Double, increment: Double) -> Double {
        max(increment, (value / increment).rounded() * increment)
    }

    private static func loadFactor(for exercise: CatalogExercise) -> Double {
        switch exercise.id {
        case 6, 7, 81:
            0.70 // deadlift patterns and rack pulls
        case 4, 56, 57, 58:
            0.70 // guided squat and leg press patterns
        case 1, 2, 5, 8, 60, 61:
            0.55 // barbell lower-body compounds
        case 16, 18, 71, 72, 73:
            0.40 // bilateral presses
        case 27, 31, 35, 78:
            0.32 // barbell rows and overhead press
        case 3, 9, 10, 11, 17, 19, 28, 36, 37, 59, 62, 79, 85, 86:
            0.12 // dumbbell and unilateral compounds; entered per implement
        case 20, 26, 29, 30, 77, 84:
            0.25 // common selectorized compound movements
        case 12, 13, 14, 21, 32, 33, 39, 40, 45, 46, 47, 53, 64, 65, 66, 70, 92:
            0.14 // cable and machine accessories
        case 15, 38, 41, 42, 43, 44, 48, 67, 68, 69, 80, 82, 83, 88, 89, 90, 91, 93:
            0.07 // free-weight isolation work
        default:
            fallbackFactor(for: exercise)
        }
    }

    private static func fallbackFactor(for exercise: CatalogExercise) -> Double {
        let equipment = exercise.equipment.lowercased()
        if equipment.contains("dumbbell") || equipment.contains("kettlebell") { return 0.08 }
        if equipment.contains("cable") || equipment.contains("machine") { return 0.14 }
        if equipment.contains("barbell") { return 0.25 }
        return 0.10
    }
}

enum SetLoadPropagation {
    static func replacingFirstLoad(
        in loads: [Double],
        from oldValue: Double,
        to newValue: Double
    ) -> [Double] {
        guard !loads.isEmpty else { return [] }

        var updated = loads
        updated[0] = newValue
        guard newValue > 0 else { return updated }

        for index in updated.indices.dropFirst()
        where updated[index] == 0 || updated[index] == oldValue {
            updated[index] = newValue
        }
        return updated
    }
}
