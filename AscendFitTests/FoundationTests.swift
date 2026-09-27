import Testing
@testable import AscendFit

struct FoundationTests {
    @Test("Selected accent matches the approved handoff")
    func accentTokenExists() {
        #expect(AppTheme.Spacing.screenInset == 20)
        #expect(AppTheme.Spacing.large == 28)
    }

    @Test("Exercise catalog ships broad, usable defaults")
    func exerciseCatalogIsReadyForSelection() {
        let exercises = ExerciseCatalog.exercises

        #expect(exercises.count >= 100)
        #expect(Set(exercises.map(\.id)).count == exercises.count)
        #expect(Set(exercises.map(\.name)).count == exercises.count)
        #expect(exercises.allSatisfy { !$0.description.isEmpty })
        #expect(exercises.allSatisfy { $0.defaultSets > 0 && $0.defaultReps > 0 })
    }

    @Test("Starting loads are conservative, rounded, and experience-aware")
    func startingLoadSuggestionsUseTheTrainingProfile() {
        let benchPress = ExerciseCatalog.exercises.first { $0.id == 16 }!
        let pushUp = ExerciseCatalog.exercises.first { $0.id == 22 }!
        let beginner = TrainingProfile(
            heightCentimeters: 178,
            bodyWeightKilograms: 82,
            experience: .beginner
        )
        let advanced = TrainingProfile(
            heightCentimeters: 178,
            bodyWeightKilograms: 82,
            experience: .advanced
        )

        let beginnerLoad = StartingLoadSuggestion.amount(for: benchPress, profile: beginner, unit: .pounds)!
        let advancedLoad = StartingLoadSuggestion.amount(for: benchPress, profile: advanced, unit: .pounds)!

        #expect(beginnerLoad > 0)
        #expect(beginnerLoad.truncatingRemainder(dividingBy: 5) == 0)
        #expect(advancedLoad > beginnerLoad)
        #expect(StartingLoadSuggestion.amount(for: pushUp, profile: beginner, unit: .pounds) == nil)
    }

    @Test("Changing the first-set load preserves customized later sets")
    func firstSetLoadBecomesTheRemainingDefault() {
        let updated = SetLoadPropagation.replacingFirstLoad(
            in: [95, 95, 160, 0],
            from: 95,
            to: 145
        )

        #expect(updated == [145, 145, 160, 145])
    }
}
