import Foundation
import Testing
@testable import AscendFit

struct HistoryProgressTests {
    @Test("Activity window spans twelve calendar weeks across DST and ranks each unit independently")
    func calendarAndQuartiles() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        calendar.firstWeekday = 2
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 12)))
        let dates = try (0..<4).map { try #require(calendar.date(byAdding: .day, value: -$0, to: now)) }
        let entries = try dates.enumerated().map { index, date in
            try workout(load: Decimal(index + 1) * 10, unit: .kilograms, at: date)
        }
        let pounds = try workout(load: 900, unit: .pounds, at: dates[0])
        let window = HistoryActivityWindow(history: entries + [pounds], now: now, calendar: calendar)
        #expect(window.days.count == 84)
        #expect(Set(window.days.map(\.date)).count == 84)
        #expect(calendar.component(.weekday, from: window.days[0].date) == 2)
        let today = try #require(window.days.first { calendar.isDate($0.date, inSameDayAs: now) })
        #expect(today.workoutCount == 2)
        #expect(today.volumes[.kilograms] == 80)
        #expect(today.volumes[.pounds] == 7200)
        #expect(window.intensity(for: today, unit: .kilograms) == 1)
        #expect(window.intensity(for: today, unit: .pounds) == 1)
        let largest = try #require(window.days.first { calendar.isDate($0.date, inSameDayAs: dates[3]) })
        #expect(window.intensity(for: largest, unit: .kilograms) == 4)
        #expect(window.days.filter(\.isFuture).count == 4)
        #expect(HistoryActivityWindow(history: [], now: now, calendar: calendar).days.allSatisfy { $0.workoutCount == 0 && $0.volumes.isEmpty })
    }

    @Test("Volume includes only recorded weighted repetitions and never merges load units")
    func meaningfulVolume() throws {
        #expect(try SetResult.weighted(reps: CompletedReps(8), load: Load(amount: 20, unit: .kilograms)).recordedLoadVolume?.amount == 160)
        #expect(try SetResult.amrap(reps: CompletedReps(10), load: Load(amount: 20, unit: .pounds)).recordedLoadVolume?.amount == 200)
        #expect(try SetResult.assistedBodyweight(reps: CompletedReps(8), assistance: Load(amount: 20, unit: .kilograms)).recordedLoadVolume == nil)
        #expect(try SetResult.bodyweight(reps: CompletedReps(8)).recordedLoadVolume == nil)
        #expect(try SetResult.timed(duration: ExerciseDuration(seconds: 30), load: Load(amount: 20, unit: .kilograms)).recordedLoadVolume == nil)
        #expect(try SetResult.amrap(reps: CompletedReps(10), load: nil).recordedLoadVolume == nil)
        let kg = try workout(load: 20, unit: .kilograms, at: Date(timeIntervalSince1970: 100))
        let lb = try workout(load: 40, unit: .pounds, at: Date(timeIntervalSince1970: 200))
        let progress = try #require(ExerciseProgress.all(in: [kg, lb]).first)
        #expect(progress.volumePoints(unit: .kilograms).map(\.amount) == [160])
        #expect(progress.volumePoints(unit: .pounds).map(\.amount) == [320])
    }

    @Test("Coach records are deterministic, require older evidence and disappear with deleted evidence")
    func recordText() throws {
        let first = try workout(load: 20, unit: .kilograms, at: Date(timeIntervalSince1970: 100))
        let next = try workout(load: 25, unit: .kilograms, at: Date(timeIntervalSince1970: 200))
        let tiedTime = try workout(load: 30, unit: .kilograms, at: Date(timeIntervalSince1970: 200))
        let lines = ExerciseProgress.recordLines(for: next.id, in: [first, next, tiedTime])
        #expect(lines == ExerciseProgress.recordLines(for: next.id, in: [tiedTime, next, first]))
        #expect(lines == ["New best: Back Squat (Barbell) · 25 kg · 8 reps · working · bilateral · kg (previous 20 kg)"])
        #expect(ExerciseProgress.recordLines(for: next.id, in: [next, tiedTime]).isEmpty)
        #expect(ExerciseProgress.recordLines(for: first.id, in: [first, next]).isEmpty)
        #expect(next.coachReadyText(recordLines: lines).contains("New bests (comparable recorded sets):\n" + lines[0]))
        #expect(first.coachReadyText(recordLines: []) == first.coachReadyText)
    }

    private func workout(load: Decimal, unit: MassUnit, at date: Date) throws -> WorkoutHistoryEntry {
        let definition = try ExerciseDefinition(name: "Back Squat", equipment: "Barbell")
        let set = try PlannedSet(prescription: .weighted(reps: RepTarget(exact: 8), load: Load(amount: load, unit: unit)))
        let exercise = try PlannedExercise(exercise: definition, sets: [set])
        var session = WorkoutSession(plan: try WorkoutPlan(title: "Strength", exercises: [exercise]))
        try session.handle(.start, at: date)
        try session.handle(.completeSet(plannedSetID: set.id,
            result: .weighted(reps: CompletedReps(8), load: Load(amount: load, unit: unit)), effort: nil, notes: nil), at: date)
        try session.handle(.finish(notes: nil), at: date)
        return try WorkoutHistoryEntry(session: session)
    }
}
