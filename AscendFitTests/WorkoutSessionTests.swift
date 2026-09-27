import Foundation
import Testing
@testable import AscendFit

@Suite("Workout session reducer")
struct WorkoutSessionTests {
    @Test("Finishing directly from pause saves one completion event and excludes paused time")
    func directFinishFromPause() throws {
        let fixture = try SessionFixture()
        let start = Date(timeIntervalSince1970: 100)
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)
        try session.handle(.start, at: start)
        try session.handle(.completeSet(
            plannedSetID: fixture.plannedSetID,
            result: .weighted(reps: CompletedReps(5), load: Load(amount: 100, unit: .kilograms)),
            effort: nil, notes: nil
        ), at: start.addingTimeInterval(5))
        try session.handle(.pause, at: start.addingTimeInterval(10))
        try session.handle(.finish(notes: "Stopped early"), at: start.addingTimeInterval(70))
        #expect(session.events.count == 4)
        #expect(try session.makeSummary().activeDuration == 10)
        #expect(session.completionNotes == "Stopped early")
        let restored = try WorkoutSession(id: session.id, plan: fixture.plan, replaying: session.events)
        #expect(restored == session)
    }

    @Test("Legacy interrupted finishing resumes without counting the recovery delay")
    func legacyFinishRecovery() throws {
        let fixture = try SessionFixture()
        let start = Date(timeIntervalSince1970: 100)
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)
        try session.handle(.start, at: start)
        try session.handle(.prepareToFinish, at: start.addingTimeInterval(20))
        var restored = try WorkoutSession(id: session.id, plan: fixture.plan, replaying: session.events)
        try restored.handle(.finish(notes: "Recovered"), at: start.addingTimeInterval(86_400))
        #expect(try restored.makeSummary().activeDuration == 20)
        #expect(restored.completionNotes == "Recovered")
        #expect(throws: DomainValidationError.self) {
            try restored.handle(.finish(notes: nil), at: start.addingTimeInterval(86_401))
        }
    }

    @Test("Exercise rest defaults persist, apply to added sets, and support turning rest off")
    func exerciseRestDefaultsReplay() throws {
        let fixture = try SessionFixture()
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)
        let date = Date(timeIntervalSince1970: 900)
        let result = SetResult.weighted(reps: try CompletedReps(5), load: try Load(amount: 100, unit: .kilograms))
        let added = PlannedSet(prescription: fixture.plan.exercises[0].sets[0].prescription)
        try session.handle(.start, at: date)
        try session.handle(.setExerciseRest(exerciseID: fixture.plannedExerciseID, duration: RestDuration(seconds: 120)), at: date)
        try session.handle(.addSet(exerciseID: fixture.plannedExerciseID, set: added), at: date)
        #expect(session.restDuration(for: added.id)?.seconds == 120)
        try session.handle(.completeSet(plannedSetID: fixture.plannedSetID, result: result, effort: nil, notes: nil), at: date)
        #expect(session.status == .resting(deadline: date.addingTimeInterval(120)))
        try session.handle(.setExerciseRest(exerciseID: fixture.plannedExerciseID, duration: RestDuration(seconds: 0)), at: date)
        #expect(session.status == .resting(deadline: date.addingTimeInterval(120)))
        try session.handle(.endRest, at: date)
        try session.handle(.completeSet(plannedSetID: fixture.secondPlannedSetID, result: result, effort: nil, notes: nil), at: date)
        #expect(session.status == .active)
        #expect(session.plan.exercises[0].sets[0].restAfter?.seconds == 90)

        let storedEvents = try JSONDecoder().decode([SessionEvent].self, from: JSONEncoder().encode(session.events))
        let restored = try WorkoutSession(id: fixture.sessionID, plan: fixture.plan, replaying: storedEvents)
        #expect(restored == session)
        #expect(restored.restDuration(for: added.id)?.seconds == 0)
    }

    @Test("Set completion starts rest from a deadline and replays exactly")
    func completionStartsRestAndReplays() throws {
        let fixture = try SessionFixture()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)

        try session.handle(.start, at: startedAt)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            ),
            at: startedAt.addingTimeInterval(10)
        )

        #expect(session.status == .resting(deadline: startedAt.addingTimeInterval(100)))

        let restored = try WorkoutSession(
            id: fixture.sessionID,
            plan: fixture.plan,
            replaying: session.events
        )
        #expect(restored == session)
    }

    @Test("Rest adjustments move the stored deadline and can end the timer")
    func restAdjustmentsPersist() throws {
        let fixture = try SessionFixture()
        let startedAt = Date(timeIntervalSince1970: 1_500)
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)

        try session.handle(.start, at: startedAt)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: try CompletedReps(5),
                    load: try Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            ),
            at: startedAt.addingTimeInterval(10)
        )
        try session.handle(.adjustRest(bySeconds: 30), at: startedAt.addingTimeInterval(20))

        #expect(session.status == .resting(deadline: startedAt.addingTimeInterval(130)))

        try session.handle(.adjustRest(bySeconds: -200), at: startedAt.addingTimeInterval(21))
        #expect(session.status == .active)

        let restored = try WorkoutSession(
            id: fixture.sessionID,
            plan: fixture.plan,
            replaying: session.events
        )
        #expect(restored == session)
    }

    @Test("Pausing preserves remaining rest even when the original deadline passes")
    func pausedRestResumesWithRemainingTime() throws {
        let fixture = try SessionFixture()
        let startedAt = Date(timeIntervalSince1970: 2_000)
        var session = WorkoutSession(plan: fixture.plan)

        try session.handle(.start, at: startedAt)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            ),
            at: startedAt
        )
        try session.handle(.pause, at: startedAt.addingTimeInterval(30))
        try session.handle(.resume, at: startedAt.addingTimeInterval(120))

        #expect(session.status == .resting(deadline: startedAt.addingTimeInterval(180)))
    }

    @Test("Undo removes only the latest completed set")
    func undoLatestCompletion() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        var session = WorkoutSession(plan: fixture.plan)

        try session.handle(.start)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            )
        )
        try session.handle(.undoLastSet)

        #expect(session.completedSets.isEmpty)
        #expect(session.status == .active)
    }

    @Test("Editing a completed set changes the result without duplicating it")
    func editCompletedSet() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        var session = WorkoutSession(plan: fixture.plan)
        try session.handle(.start)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            )
        )
        let completedSetID = try #require(session.completedSets.first?.id)

        try session.handle(
            .editSet(
                completedSetID: completedSetID,
                result: .weighted(
                    reps: CompletedReps(4),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: .rpe(RPE(9)),
                notes: "Hard rep"
            )
        )

        #expect(session.completedSets.count == 1)
        #expect(session.completedSets[0].notes == "Hard rep")
        let editedReps = try CompletedReps(4)
        let editedLoad = try Load(amount: 100, unit: .kilograms)
        #expect(session.completedSets[0].result == .weighted(reps: editedReps, load: editedLoad))
    }

    @Test("Set adjustments cascade through pending sets without changing completed work")
    func adjustedTargetsProtectCompletedSetsAndReplay() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)
        let firstAdjustment = SetResult.weighted(
            reps: try CompletedReps(4),
            load: try Load(amount: 90, unit: .kilograms)
        )
        let laterAdjustment = SetResult.weighted(
            reps: try CompletedReps(3),
            load: try Load(amount: 80, unit: .kilograms)
        )

        try session.handle(.start)
        try session.handle(
            .adjustRemainingSets(
                exerciseID: fixture.plannedExerciseID,
                result: firstAdjustment
            )
        )
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: firstAdjustment,
                effort: nil,
                notes: nil
            )
        )
        try session.handle(
            .adjustRemainingSets(
                exerciseID: fixture.plannedExerciseID,
                result: laterAdjustment
            )
        )

        #expect(session.completedSets[0].result == firstAdjustment)
        #expect(session.resultOverride(for: fixture.plannedSetID) == firstAdjustment)
        #expect(session.resultOverride(for: fixture.secondPlannedSetID) == laterAdjustment)

        let restored = try WorkoutSession(
            id: fixture.sessionID,
            plan: fixture.plan,
            replaying: session.events
        )
        #expect(restored == session)
    }

    @Test("Skipped sets cannot later be completed silently")
    func skippedSetRejectsCompletion() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        var session = WorkoutSession(plan: fixture.plan)
        try session.handle(.start)
        try session.handle(.skipSet(plannedSetID: fixture.plannedSetID))

        #expect(throws: DomainValidationError.alreadySkipped(fixture.plannedSetID)) {
            try session.handle(
                .completeSet(
                    plannedSetID: fixture.plannedSetID,
                    result: .weighted(
                        reps: CompletedReps(5),
                        load: Load(amount: 100, unit: .kilograms)
                    ),
                    effort: nil,
                    notes: nil
                )
            )
        }
    }

    @Test("In-workout plan changes survive event replay")
    func planChangesReplay() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        let addedSet = try PlannedSet(
            prescription: .bodyweight(reps: RepTarget(exact: 12))
        )
        let replacement = try ExerciseDefinition(name: "Front Squat")
        var session = WorkoutSession(id: fixture.sessionID, plan: fixture.plan)
        try session.handle(.start)
        try session.handle(.addSet(exerciseID: fixture.plannedExerciseID, set: addedSet))
        try session.handle(
            .replaceExercise(
                plannedExerciseID: fixture.plannedExerciseID,
                replacement: replacement
            )
        )

        let restored = try WorkoutSession(
            id: fixture.sessionID,
            plan: fixture.plan,
            replaying: session.events
        )

        #expect(restored == session)
    }

    @Test("Summary excludes paused time and totals meaningful volume")
    func completedSummary() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        let start = Date(timeIntervalSince1970: 3_000)
        var session = WorkoutSession(plan: fixture.plan)
        try session.handle(.start, at: start)
        try session.handle(.pause, at: start.addingTimeInterval(10))
        try session.handle(.resume, at: start.addingTimeInterval(40))
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            ),
            at: start.addingTimeInterval(50)
        )
        try session.handle(.prepareToFinish, at: start.addingTimeInterval(60))
        try session.handle(.finish(notes: "Felt strong"), at: start.addingTimeInterval(61))

        let summary = try session.makeSummary()

        #expect(summary.activeDuration == 30)
        #expect(summary.completedSetCount == 1)
        #expect(summary.modifiedSetCount == 0)
        #expect(summary.volumeByUnit[.kilograms] == 500)
        #expect(summary.notes == "Felt strong")
    }

    @Test("Coach summary preserves actual changes, skipped work, and notes")
    func coachReadySummaryIsDeterministic() throws {
        let fixture = try SessionFixture(restSeconds: 0)
        let start = Date(timeIntervalSince1970: 4_000)
        var session = WorkoutSession(plan: fixture.plan)
        try session.handle(.start, at: start)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(4),
                    load: Load(amount: 90, unit: .kilograms)
                ),
                effort: .rir(RIR(1)),
                notes: "Left shoulder felt tight"
            ),
            at: start.addingTimeInterval(10)
        )
        try session.handle(.skipSet(plannedSetID: fixture.secondPlannedSetID), at: start.addingTimeInterval(11))
        try session.handle(.prepareToFinish, at: start.addingTimeInterval(12))
        try session.handle(.finish(notes: "Reduced load intentionally"), at: start.addingTimeInterval(13))

        let text = try WorkoutHistoryEntry(session: session).coachReadyText

        #expect(text.contains("90 kg × 4 (planned 100 kg × 5) · 1 RIR · Left shoulder felt tight"))
        #expect(text.contains("Skipped (planned 100 kg × 5)"))
        #expect(text.contains("Workout notes: Reduced load intentionally"))
    }

    @Test("The final set does not start a rest interval")
    func finalSetSkipsRest() throws {
        let fixture = try SessionFixture()
        var session = WorkoutSession(plan: fixture.plan)
        try session.handle(.start)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.plannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            )
        )
        try session.handle(.endRest)
        try session.handle(
            .completeSet(
                plannedSetID: fixture.secondPlannedSetID,
                result: .weighted(
                    reps: CompletedReps(5),
                    load: Load(amount: 100, unit: .kilograms)
                ),
                effort: nil,
                notes: nil
            )
        )

        #expect(session.status == .active)
    }
}

private struct SessionFixture {
    let sessionID = UUID()
    let plannedExerciseID: UUID
    let plannedSetID: UUID
    let secondPlannedSetID: UUID
    let plan: WorkoutPlan

    init(restSeconds: Int = 90) throws {
        let plannedSetID = UUID()
        let plannedExerciseID = UUID()
        self.plannedSetID = plannedSetID
        self.plannedExerciseID = plannedExerciseID
        let plannedSet = try PlannedSet(
            id: plannedSetID,
            prescription: .weighted(
                reps: RepTarget(exact: 5),
                load: Load(amount: 100, unit: .kilograms)
            ),
            restAfter: RestDuration(seconds: restSeconds)
        )
        let secondSet = try PlannedSet(
            prescription: .weighted(
                reps: RepTarget(exact: 5),
                load: Load(amount: 100, unit: .kilograms)
            ),
            restAfter: RestDuration(seconds: restSeconds)
        )
        secondPlannedSetID = secondSet.id
        let exercise = try PlannedExercise(
            id: plannedExerciseID,
            exercise: ExerciseDefinition(name: "Back Squat"),
            sets: [plannedSet, secondSet]
        )
        plan = try WorkoutPlan(title: "Lower A", exercises: [exercise])
    }
}
