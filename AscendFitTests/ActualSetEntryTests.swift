import Foundation
import Testing
@testable import AscendFit

@Suite("Optional actual set entry")
struct ActualSetEntryTests {
    @Test("Optional weight and duration can be added, removed, and restored without changing units")
    func optionalValues() throws {
        var amrap = ActiveSetDraft(result: .amrap(reps: try CompletedReps(12), load: nil))
        amrap.setOptionalLoad(true, unit: .kilograms)
        amrap.loadText = "12.5"
        #expect(amrap.result == .amrap(reps: try CompletedReps(12), load: try Load(amount: 12.5, unit: .kilograms)))
        amrap.setOptionalLoad(false, unit: .pounds)
        #expect(amrap.result == .amrap(reps: try CompletedReps(12), load: nil))
        amrap.setOptionalLoad(true, unit: .pounds)
        #expect(amrap.result == .amrap(reps: try CompletedReps(12), load: try Load(amount: 12.5, unit: .kilograms)))
        amrap.loadText = "invalid"
        #expect(amrap.result == nil)
        amrap.setOptionalLoad(false, unit: .pounds)
        #expect(amrap.result != nil)

        let distance = try ExerciseDistance(amount: 400, unit: .meters)
        var run = ActiveSetDraft(result: .distance(distance: distance, duration: nil))
        run.setOptionalDuration(true)
        run.durationText = "95"
        #expect(run.result == .distance(distance: distance, duration: try ExerciseDuration(seconds: 95)))
        run.setOptionalDuration(false)
        #expect(run.result == .distance(distance: distance, duration: nil))
        run.setOptionalDuration(true)
        #expect(run.durationText == "95")
    }

    @Test("Effort editor preserves the exact recorded note and can clear effort independently")
    func effortAndNotes() throws {
        let note = "  Left side felt tight.\nStopped at eight.  "
        var draft = SetDetailsDraft(effort: .rpe(try RPE(7.5)), notes: note)
        #expect(draft.notes == note)
        #expect(draft.effort == .rpe(try RPE(7.5)))
        draft.kind = .rir
        draft.value = 2
        #expect(draft.effort == .rir(try RIR(2)))
        draft.kind = .none
        #expect(draft.effort == nil)
        #expect(draft.notes == note)
        #expect(draft.hasDetails)
    }

    @Test("Four or more reps stays distinct from exactly four through persistence and editing")
    func fourOrMoreReps() throws {
        let effort = EffortTarget.rirAtLeast(try RIR(4))
        let restored = try JSONDecoder().decode(EffortTarget.self, from: JSONEncoder().encode(effort))
        #expect(restored == effort)
        #expect(SetDetailsDraft(effort: restored).effort == effort)
        #expect(restored != .rir(try RIR(4)))
    }

    @Test("Tempo supports explosive lifting and ignores hidden disabled values")
    func tempoTarget() throws {
        var draft = SetTempoDraft()
        draft.lowering = -1
        #expect(try draft.value() == nil)
        draft.isEnabled = true
        #expect(throws: DomainValidationError.self) { try draft.value() }
        draft.lowering = 3
        draft.explosiveLift = true
        let value = try draft.value()
        let tempo = try #require(value)
        #expect(tempo.eccentric == .controlled(seconds: 3))
        #expect(tempo.concentric == .explosive)
        #expect(tempo.bottomPause == .controlled(seconds: 0))
    }
}
