import Foundation
import Testing
@testable import AscendFit

struct PreviousPerformanceTests {
    @Test("Previous performance uses the newest matching set's edited actuals and original units")
    func latestActualResult() throws {
        let exercise = try ExerciseDefinition(name: "Back Squat", equipment: "Barbell")
        let target = try makeSet()
        let old = try history(exercise: exercise, sets: [target], at: 100)
        let latest = try history(exercise: exercise, sets: [target], at: 200, editedReps: 6)
        let newDefinition = try ExerciseDefinition(name: " back squat ", equipment: "barbell")
        let current = try makeSet()

        let found = try #require(PreviousSetPerformance.find(
            exercise: newDefinition, set: current, exerciseSets: [current], history: [old, latest]
        ))
        #expect(found.date == latest.summary.endedAt)
        #expect(found.result == latest.session.completedSets[0].result)
        #expect(found.result.summaryText == "80 kg × 6")
    }

    @Test("Warm-ups do not shift working-set positions and missing recent results stay empty")
    func comparablePositionsAndMissingResults() throws {
        let exercise = try ExerciseDefinition(name: "Back Squat", equipment: "Barbell")
        let warmup = try makeSet(role: .warmUp)
        let first = try makeSet()
        let second = try makeSet()
        let older = try history(exercise: exercise, sets: [first, second], at: 100)
        let recent = try history(exercise: exercise, sets: [warmup, first, second], at: 200, skipLast: true)
        let current = try makeSet()
        let extra = try makeSet()
        #expect(PreviousSetPerformance.find(
            exercise: exercise, set: current, exerciseSets: [current, extra], history: [older, recent]
        )?.result == recent.session.completedSets[1].result)
        #expect(PreviousSetPerformance.find(
            exercise: exercise, set: extra, exerciseSets: [current, extra], history: [older, recent]
        ) == nil)
    }

    @Test("Equipment, side, replacements, and absent history cannot imply a false match")
    func unrelatedPerformanceIsExcluded() throws {
        let barbell = try ExerciseDefinition(name: "Row", equipment: "Barbell")
        let dumbbell = try ExerciseDefinition(name: "Row", equipment: "Dumbbell")
        let set = try makeSet()
        let entry = try history(exercise: barbell, sets: [set], at: 100, replacement: dumbbell)
        #expect(PreviousSetPerformance.find(
            exercise: barbell, set: set, exerciseSets: [set], history: [entry]
        ) == nil)
        #expect(PreviousSetPerformance.find(
            exercise: dumbbell, set: set, exerciseSets: [set], history: [entry]
        ) != nil)
        let left = try makeSet(side: .left)
        #expect(PreviousSetPerformance.find(
            exercise: dumbbell, set: left, exerciseSets: [left], history: [entry]
        ) == nil)
        #expect(PreviousSetPerformance.find(
            exercise: dumbbell, set: set, exerciseSets: [set], history: []
        ) == nil)
    }

    @Test("Replacing a movement after logging preserves both previous-performance identities")
    func mixedReplacementHistory() throws {
        let squat = try ExerciseDefinition(name: "Back Squat", equipment: "Barbell")
        let press = try ExerciseDefinition(name: "Leg Press", equipment: "Machine")
        let sets = try [makeSet(), makeSet()]
        let planned = try PlannedExercise(exercise: squat, sets: sets)
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Legs", exercises: [planned]))
        let date = Date(timeIntervalSince1970: 100)
        try session.handle(.start, at: date)
        let first = SetResult.weighted(reps: try CompletedReps(8), load: try Load(amount: 80, unit: .kilograms))
        let second = SetResult.weighted(reps: try CompletedReps(10), load: try Load(amount: 100, unit: .kilograms))
        try session.handle(.completeSet(plannedSetID: sets[0].id, result: first, effort: nil, notes: nil), at: date)
        try session.handle(.replaceExercise(plannedExerciseID: planned.id, replacement: press), at: date)
        try session.handle(.completeSet(plannedSetID: sets[1].id, result: second, effort: nil, notes: nil), at: date)
        try session.handle(.finish(notes: nil), at: date)
        let entry = try WorkoutHistoryEntry(session: session)
        let current = try makeSet()
        #expect(PreviousSetPerformance.find(exercise: squat, set: current, exerciseSets: [current], history: [entry])?.result == first)
        #expect(PreviousSetPerformance.find(exercise: press, set: current, exerciseSets: [current], history: [entry])?.result == second)
        #expect(entry.coachReadyText.contains("Leg Press (replaces Back Squat)"))
    }

    private func makeSet(role: SetRole = .working, side: ExerciseSide = .bilateral) throws -> PlannedSet {
        PlannedSet(
            role: role,
            prescription: .weighted(reps: try RepTarget(exact: 8), load: try Load(amount: 80, unit: .kilograms)),
            side: side
        )
    }

    private func history(
        exercise: ExerciseDefinition,
        sets: [PlannedSet],
        at timestamp: TimeInterval,
        editedReps: Int? = nil,
        skipLast: Bool = false,
        replacement: ExerciseDefinition? = nil
    ) throws -> WorkoutHistoryEntry {
        let planned = try PlannedExercise(exercise: exercise, sets: sets)
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Training", exercises: [planned]))
        let date = Date(timeIntervalSince1970: timestamp)
        try session.handle(.start, at: date)
        if let replacement {
            try session.handle(.replaceExercise(plannedExerciseID: planned.id, replacement: replacement), at: date)
        }
        for (index, set) in sets.enumerated() {
            if skipLast && index == sets.count - 1 {
                try session.handle(.skipSet(plannedSetID: set.id), at: date)
            } else {
                try session.handle(.completeSet(
                    plannedSetID: set.id,
                    result: .weighted(reps: CompletedReps(8), load: Load(amount: 80, unit: .kilograms)),
                    effort: nil, notes: nil
                ), at: date)
            }
        }
        if let editedReps {
            try session.handle(.editSet(
                completedSetID: session.completedSets[0].id,
                result: .weighted(reps: CompletedReps(editedReps), load: Load(amount: 80, unit: .kilograms)),
                effort: nil, notes: nil
            ), at: date)
        }
        try session.handle(.prepareToFinish, at: date)
        try session.handle(.finish(notes: nil), at: date)
        return try WorkoutHistoryEntry(session: session)
    }
}
