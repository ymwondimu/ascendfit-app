import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    @EnvironmentObject private var model: AppModel
    @State private var adjustedResults: [UUID: SetResult] = [:]
    @State private var manuallyAdjustedSetIDs: Set<UUID> = []
    @State private var invalidResultIDs: Set<UUID> = []
    @State private var editorRequest: SetEditorRequest?
    @State private var effortPrompt: ExerciseEffortPromptRequest?
    @State private var setDetails: [UUID: SetDetailsDraft] = [:]
    @State private var editorRevision = 0
    @State private var isShowingOverview = false
    @State private var exerciseInfo: ExerciseDefinition?
    @State private var isConfirmingEnd = false
    @State private var completedRestDeadline: Date?
    @State private var workoutNotes = ""
    @State private var isEditingRest = false
    @State private var isReplacingExercise = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            Group {
                if let session = model.activeSession {
                    content(for: session)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $editorRequest) { request in
            ActiveSetEditor(request: request) { result, details in
                if let completedSetID = request.completedSetID {
                    let saved = await model.editCompletedSet(completedSetID, result: result, effort: details.effort, notes: details.notes)
                    if saved {
                        adjustedResults[request.plannedSetID] = result
                        setDetails[request.plannedSetID] = details
                        editorRevision += 1
                    }
                    return saved
                } else {
                    adjustedResults[request.plannedSetID] = result
                    setDetails[request.plannedSetID] = details
                    invalidResultIDs.remove(request.plannedSetID)
                    manuallyAdjustedSetIDs.remove(request.plannedSetID)
                    editorRevision += 1
                    return true
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $effortPrompt) { request in
            ExerciseEffortSheet(exerciseName: request.exerciseName) { repsLeft in
                guard let repsLeft else { return true }
                guard let value = try? RIR(repsLeft) else { return false }
                let effort: EffortTarget = repsLeft == 4 ? .rirAtLeast(value) : .rir(value)
                return await model.editCompletedSet(
                    request.completedSetID,
                    result: request.result,
                    effort: effort,
                    notes: request.notes
                )
            }
            .presentationDetents([.height(390)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingOverview) {
            WorkoutOverviewView().environmentObject(model)
        }
        .sheet(item: $exerciseInfo) { exercise in
            ExerciseInfoSheet(exercise: exercise)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isEditingRest) {
            if let context = model.currentSetContext, let session = model.activeSession {
                ExerciseRestEditor(
                    exerciseID: context.exercise.id,
                    initialSeconds: session.restDuration(for: context.set.id)?.seconds ?? 0
                )
                .environmentObject(model)
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $isReplacingExercise) {
            if let session = model.activeSession, let context = model.currentSetContext {
                let pending = (context.exercise.sets + session.addedSets[context.exercise.id, default: []]).filter { set in
                    !session.skippedSetIDs.contains(set.id)
                        && !session.completedSets.contains(where: { $0.plannedSetID == set.id })
                }
                ExerciseReplacementPicker(remainingSets: pending) { replacement in
                    await model.replaceCurrentExercise(with: replacement)
                }
            }
        }
        .alert("End workout?", isPresented: $isConfirmingEnd) {
            Button("Keep training", role: .cancel) {}
            Button("Finish and save") {
                Task { await model.finishWorkout() }
            }
            Button("Discard workout", role: .destructive) {
                Task { await model.discardWorkout() }
            }
        } message: {
            Text("Finish saves completed and skipped sets. Discard removes this session from your workout history.")
        }
    }

    @ViewBuilder
    private func content(for session: WorkoutSession) -> some View {
        if case .completed = session.status, let summary = model.latestSummary {
            completion(summary)
        } else if case .completing = session.status {
            finishPrompt(recovering: true)
        } else if let context = model.currentSetContext {
            VStack(spacing: 0) {
                workoutProgressHeader(session: session, context: context)
                    .padding(.bottom, 10)

                if case let .resting(deadline) = session.status {
                    rest(deadline: deadline, context: context, session: session)
                } else if case .paused = session.status {
                    paused(context: context, session: session)
                } else {
                    List {
                        activeSet(context, session: session)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(AppTheme.background)
                            .listRowSeparator(.hidden)
                        activeLedger(context: context, session: session).listSection
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        logSetButton(context: context, session: session)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .background(AppTheme.background)
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }
            }
        } else {
            finishPrompt(recovering: false)
        }
    }

    private func workoutProgressHeader(
        session: WorkoutSession,
        context: CurrentSetContext
    ) -> some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(session.elapsedText(at: timeline.date))
                    .font(.system(size: 15, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.contentSecondary)
            }

            Spacer()

            Text("Exercise \(context.exercisePosition) of \(context.exerciseTotal)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.contentSecondary)

            Menu {
                Button("Workout overview", systemImage: "list.bullet") {
                    isShowingOverview = true
                }
                Button("Replace exercise", systemImage: "arrow.triangle.2.circlepath") {
                    isReplacingExercise = true
                }
                .disabled(session.status != .active)

                Button("Undo last set", systemImage: "arrow.uturn.backward") {
                    Task { await model.undoLastSet() }
                }
                .disabled(session.completedSets.isEmpty)

                Divider()

                if session.status.isPaused {
                    Button("Resume workout", systemImage: "play.fill") {
                        Task { await model.resumeWorkout() }
                    }
                } else {
                    Button("Pause workout", systemImage: "pause.fill") {
                        Task { await model.pauseWorkout() }
                    }
                }

                Button("End workout", systemImage: "stop.fill", role: .destructive) {
                    isConfirmingEnd = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.contentPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.surfacePrimary, in: Circle())
            }
            .accessibilityLabel("Workout options")
            .accessibilityIdentifier("active-workout-menu")
        }
        .frame(minHeight: 44)
    }

    private func activeSet(
        _ context: CurrentSetContext,
        session: WorkoutSession
    ) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("EXERCISE \(String(format: "%02d", context.exercisePosition)) OF \(String(format: "%02d", context.exerciseTotal))")
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.action)
                    Spacer()
                    Button {
                        exerciseInfo = currentExercise(context, session: session)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .accessibilityLabel("About \(currentExercise(context, session: session).name)")
                    .accessibilityIdentifier("exercise-info")
                }
                Spacer(minLength: 8)
                Text(currentExercise(context, session: session).name)
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.7)
                    .foregroundStyle(.white)
                if let cue = exerciseCue(context, session: session) {
                    Text(cue)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.83))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("exercise-cues")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 145, alignment: .bottomLeading)
            .background {
                GeometryReader { geometry in
                    ZStack {
                        if currentExercise(context, session: session).name.caseInsensitiveCompare("Back Squat") == .orderedSame {
                            Image("CampaignSquat")
                                .resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } else {
                            LinearGradient(colors: [AppTheme.surfaceTertiary, AppTheme.surfacePrimary], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                        LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.74), .black.opacity(0.90)], startPoint: .top, endPoint: .bottom)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            let restSeconds = session.restDuration(for: context.set.id)?.seconds ?? 0
            Button {
                isEditingRest = true
            } label: {
                Label(restSeconds == 0 ? "Rest between sets: Off" : "Rest between sets: \(restSeconds) sec", systemImage: "timer")
                    .font(.subheadline)
                    .frame(minHeight: 46)
            }
            .foregroundStyle(AppTheme.action)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint("Change the rest after upcoming sets of this exercise")
            .accessibilityIdentifier("exercise-rest-default")

            Spacer(minLength: 4)

            Text(
                adjustedResults[context.set.id]?.displayText
                    ?? session.resultOverride(for: context.set.id)?.displayText
                    ?? context.set.prescription.displayTarget
            )
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .tracking(-1.2)
                .minimumScaleFactor(0.52)
                .lineLimit(1)
                .foregroundStyle(AppTheme.contentPrimary)
                .frame(maxWidth: .infinity)

            if let group = context.exercise.group, let round = session.groupRound(for: context.set.id) {
                Text("\(group.kind == .superset ? "Superset" : "Circuit") · Round \(round)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentContent)
                    .accessibilityIdentifier("active-group-round")
            }

            Text("WORKING SET \(context.setPosition) OF \(context.setTotal)")
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(AppTheme.action)
                .accessibilityLabel("Set \(context.setPosition) of \(context.setTotal)")
                .padding(.top, 4)

            if context.exercise.group != nil,
               let next = session.executionOrder.first(where: { item in
                   item.set.id != context.set.id && !session.skippedSetIDs.contains(item.set.id)
                       && !session.completedSets.contains(where: { result in result.plannedSetID == item.set.id })
               }) {
                Text("Next: \(session.exerciseDefinition(for: next.set.id)?.name ?? next.exercise.exercise.name)")
                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
            }

            if context.set.role != .working || context.set.side != .bilateral || context.set.effortTarget != nil || context.set.tempo != nil {
                Text(setDetails(context.set))
                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    .padding(.top, 4)
            }

            if let previous = model.previousPerformance(for: context) {
                Text("Last time (\(previous.date.formatted(date: .abbreviated, time: .omitted))): \(previous.result.summaryText)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.contentSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("previous-set-performance")
                    .padding(.top, 6)
            }

            if let initialResult = context.set.prescription.defaultResultForEditing {
                InlineCurrentSetEditor(
                    initialResult: adjustedResults[context.set.id]
                        ?? session.resultOverride(for: context.set.id)
                        ?? initialResult
                ) { result in
                    if let result {
                        updateRemainingDrafts(
                            with: result,
                            from: context,
                            in: session
                        )
                        invalidResultIDs.remove(context.set.id)
                    } else {
                        adjustedResults[context.set.id] = nil
                        invalidResultIDs.insert(context.set.id)
                    }
                }
                .id("\(context.set.id)-\(editorRevision)")
                .padding(.top, 10)
            }

        }
    }

    private func activeLedger(context: CurrentSetContext, session: WorkoutSession) -> CurrentExerciseSetLedger {
        CurrentExerciseSetLedger(
            session: session,
            context: context,
            draftResults: adjustedResults,
            onEditCompleted: editCompletedSet,
            onEditCurrent: { editCurrentSet(context, session: session) },
            onAddSet: {
                let result = adjustedResults[context.set.id]
                    ?? session.resultOverride(for: context.set.id)
                Task { await model.addSetToCurrentExercise(result: result) }
            },
            onDeleteSet: { setID in Task { await model.deleteSet(setID) } }
        )
    }

    private func editCurrentSet(_ context: CurrentSetContext, session: WorkoutSession) {
        guard let result = adjustedResults[context.set.id]
            ?? session.resultOverride(for: context.set.id)
            ?? context.set.prescription.defaultResultForEditing else { return }
        editorRequest = SetEditorRequest(
            plannedSetID: context.set.id, completedSetID: nil,
            title: "Set details", initialResult: result,
            initialDetails: setDetails[context.set.id] ?? SetDetailsDraft()
        )
    }

    private func logSetButton(context: CurrentSetContext, session: WorkoutSession) -> some View {
        Button("Log set") {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let result = adjustedResults[context.set.id]
                ?? session.resultOverride(for: context.set.id)
            let shouldUpdateRemaining = manuallyAdjustedSetIDs.contains(context.set.id)
            let shouldAskEffort = shouldAskEffortAfterSet(context: context, session: session)
            Task {
                let saved = await model.logCurrentSet(
                    result: result,
                    updateRemainingSets: shouldUpdateRemaining,
                    effort: setDetails[context.set.id]?.effort,
                    notes: setDetails[context.set.id]?.notes
                )
                if saved, shouldAskEffort,
                   let completed = model.activeSession?.completedSets.last(where: { $0.plannedSetID == context.set.id }) {
                    effortPrompt = ExerciseEffortPromptRequest(
                        completedSetID: completed.id,
                        result: completed.result,
                        notes: completed.notes,
                        exerciseName: currentExercise(context, session: session).name
                    )
                }
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(invalidResultIDs.contains(context.set.id))
    }

    private func shouldAskEffortAfterSet(context: CurrentSetContext, session: WorkoutSession) -> Bool {
        guard context.set.role == .working, setDetails[context.set.id]?.effort == nil else { return false }
        switch context.set.prescription {
        case .weighted, .bodyweight, .assistedBodyweight, .amrap: break
        case .timed, .distance: return false
        }
        let completedIDs = Set(session.completedSets.map(\.plannedSetID))
        return (context.exercise.sets + session.addedSets[context.exercise.id, default: []])
            .filter { !session.skippedSetIDs.contains($0.id) && !completedIDs.contains($0.id) }
            .allSatisfy { $0.id == context.set.id }
    }

    private func currentExercise(_ context: CurrentSetContext, session: WorkoutSession) -> ExerciseDefinition {
        session.exerciseDefinition(for: context.set.id) ?? context.exercise.exercise
    }

    private func exerciseCue(_ context: CurrentSetContext, session: WorkoutSession) -> String? {
        if session.exerciseReplacements[context.exercise.id] == nil, let notes = context.exercise.notes {
            return notes
        }
        let exercise = session.exerciseReplacements[context.exercise.id] ?? context.exercise.exercise
        return ExerciseCatalog.exercises.first {
            $0.definition.id == exercise.id || $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame
                || $0.aliases.contains(where: { $0.caseInsensitiveCompare(exercise.name) == .orderedSame })
        }?.executionCue ?? exercise.description
    }

    private func rest(
        deadline: Date,
        context: CurrentSetContext,
        session: WorkoutSession
    ) -> some View {
        VStack(spacing: 0) {
            Text("RESTING BEFORE")
                .font(.caption.weight(.medium))
                .tracking(1.1)
                .foregroundStyle(AppTheme.contentTertiary)
            Text(currentExercise(context, session: session).name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.contentPrimary)
                .padding(.top, 6)

            Spacer(minLength: 18)

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let remaining = max(0, Int(ceil(deadline.timeIntervalSince(timeline.date))))
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.accentContent)
                    .task(id: remaining) {
                        if remaining == 0, completedRestDeadline != deadline {
                            completedRestDeadline = deadline
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            UIAccessibility.post(
                                notification: .announcement,
                                argument: "Rest complete. Set \(context.setPosition) is next."
                            )
                            await model.skipRest()
                        }
                    }
            }

            Text("Next: set \(context.setPosition) of \(context.setTotal)")
                .font(.body.monospacedDigit())
                .foregroundStyle(AppTheme.contentSecondary)
                .padding(.top, 8)

            HStack(spacing: 10) {
                Button {
                    Task { await model.adjustRest(by: -30) }
                } label: {
                    Label("30 sec", systemImage: "minus")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityLabel("Shorten rest by 30 seconds")
                .accessibilityIdentifier("shorten-rest")

                Button {
                    Task { await model.adjustRest(by: 30) }
                } label: {
                    Label("30 sec", systemImage: "plus")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityLabel("Extend rest by 30 seconds")
                .accessibilityIdentifier("extend-rest")
            }
            .padding(.top, 20)

            Button("Pause rest") {
                Task { await model.pauseWorkout() }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .padding(.top, 10)

            Button("Skip rest") {
                Task { await model.skipRest() }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, 10)

            Spacer(minLength: 18)

            CurrentExerciseSetLedger(
                session: session,
                context: context,
                draftResults: adjustedResults,
                onEditCompleted: editCompletedSet,
                onEditCurrent: { editCurrentSet(context, session: session) },
                onAddSet: {
                    let result = adjustedResults[context.set.id]
                        ?? session.resultOverride(for: context.set.id)
                    Task { await model.addSetToCurrentExercise(result: result) }
                },
                onDeleteSet: { setID in Task { await model.deleteSet(setID) } }
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func paused(
        context: CurrentSetContext,
        session: WorkoutSession
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            Image(systemName: "pause.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(AppTheme.accentContent)
            Text("Workout paused")
                .font(.title.bold())
                .foregroundStyle(AppTheme.contentPrimary)
                .padding(.top, 12)
            Text("Next: \(currentExercise(context, session: session).name) · set \(context.setPosition) of \(context.setTotal)")
                .font(.body)
                .foregroundStyle(AppTheme.contentSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Button("Resume workout") {
                Task { await model.resumeWorkout() }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, 24)

            Spacer(minLength: 18)

            CurrentExerciseSetLedger(
                session: session,
                context: context,
                draftResults: adjustedResults,
                onEditCompleted: editCompletedSet,
                onEditCurrent: { editCurrentSet(context, session: session) },
                onAddSet: {
                    let result = adjustedResults[context.set.id]
                        ?? session.resultOverride(for: context.set.id)
                    Task { await model.addSetToCurrentExercise(result: result) }
                },
                onDeleteSet: { setID in Task { await model.deleteSet(setID) } }
            )
        }
    }

    private func setDetails(_ set: PlannedSet) -> String {
        var details: [String] = []
        if set.role != .working { details.append(set.role == .warmUp ? "Warm-up" : set.role.rawValue.capitalized) }
        if set.side != .bilateral { details.append(set.side == .perSide ? "Per side" : set.side.rawValue.capitalized) }
        switch set.effortTarget {
        case let .rpe(value): details.append("RPE \(value.value.formatted())")
        case let .rir(value): details.append("RIR \(value.value)")
        case let .rirAtLeast(value): details.append("\(value.value)+ reps left")
        case nil: break
        }
        if let tempo = set.tempo {
            let phases = [tempo.eccentric, tempo.bottomPause, tempo.concentric, tempo.topPause].map { phase in
                switch phase {
                case let .controlled(seconds): return seconds.formatted()
                case .explosive: return "X"
                }
            }
            details.append("Tempo " + phases.joined(separator: "–"))
        }
        return details.joined(separator: " · ")
    }

    private func updateRemainingDrafts(
        with result: SetResult,
        from context: CurrentSetContext,
        in session: WorkoutSession
    ) {
        let sets = context.exercise.sets + session.addedSets[context.exercise.id, default: []]
        guard let currentIndex = sets.firstIndex(where: { $0.id == context.set.id }) else { return }

        for set in sets[currentIndex...] where
            !session.completedSets.contains(where: { $0.plannedSetID == set.id })
                && !session.skippedSetIDs.contains(set.id)
                && set.prescription.accepts(result) {
            adjustedResults[set.id] = result
        }
        manuallyAdjustedSetIDs.insert(context.set.id)
    }

    private func editCompletedSet(_ completedSet: CompletedSet) {
        editorRequest = SetEditorRequest(
            plannedSetID: completedSet.plannedSetID,
            completedSetID: completedSet.id,
            title: "Edit completed set",
            initialResult: completedSet.result,
            initialDetails: SetDetailsDraft(effort: completedSet.effort, notes: completedSet.notes)
        )
    }

    private func finishPrompt(recovering: Bool) -> some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            Text(recovering ? "Finish saving your workout" : "All sets logged")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.contentPrimary)

            if recovering {
                Text("Your recorded sets are safe. Finish to save this workout to History.")
                    .font(.body)
                    .foregroundStyle(AppTheme.contentSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("How did the workout feel? (optional)", text: $workoutNotes, axis: .vertical)
                .lineLimit(2 ... 4)
                .padding(14)
                .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(AppTheme.contentPrimary)

            Button("Finish workout") {
                Task { await model.finishWorkout(notes: workoutNotes) }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(model.isFinishing)
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.contentSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func completion(_ summary: WorkoutSummary) -> some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accent)
            Text("Workout complete")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.contentPrimary)
            Text("\(summary.completedSetCount) sets · \(Int(summary.activeDuration / 60)) min")
                .font(.title3.monospacedDigit())
                .foregroundStyle(AppTheme.contentSecondary)

            HStack(spacing: 20) {
                completionMetric("Modified", value: summary.modifiedSetCount)
                completionMetric("Skipped", value: summary.skippedSetCount)
            }

            if let session = model.activeSession,
               let entry = try? WorkoutHistoryEntry(session: session) {
                ShareLink(item: model.coachReadyText(for: entry)) {
                    Label("Share coach update", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier("share-coach-update")
            }

            Button("Done") {
                model.closeCompletedWorkout()
            }
            .buttonStyle(SecondaryActionButtonStyle())
            Spacer()
        }
    }

    private func completionMetric(_ label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.contentPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.contentTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CurrentExerciseSetLedger: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: WorkoutSession
    let context: CurrentSetContext
    let draftResults: [UUID: SetResult]
    let onEditCompleted: (CompletedSet) -> Void
    let onEditCurrent: () -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (UUID) -> Void

    private var sets: [PlannedSet] {
        (context.exercise.sets + session.addedSets[context.exercise.id, default: []])
            .filter { !session.skippedSetIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            List {
                rows
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
            .frame(height: CGFloat(sets.count) * (dynamicTypeSize.isAccessibilitySize ? 88 : 52))
        }
        .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    var listSection: some View {
        Section {
            rows
        } header: {
            header
                .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var header: some View {
        adaptiveLayout {
            Text("SETS")
                .font(.caption2.weight(.medium))
                .tracking(1.1)
                .foregroundStyle(AppTheme.contentTertiary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Text("\(completedCount) of \(sets.count) complete")
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.contentTertiary)

            Button(action: onAddSet) {
                Label("Add set", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentContent)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(AppTheme.surfaceSecondary, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!session.status.isActivelyTraining)
            .accessibilityIdentifier("add-set")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var rows: some View {
        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
            ledgerRow(index: index, set: set)
                .listRowInsets(EdgeInsets())
                .listRowBackground(AppTheme.surfacePrimary)
                .listRowSeparatorTint(AppTheme.contentTertiary.opacity(0.16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if session.completedSets.contains(where: { $0.plannedSetID == set.id }) == false,
                       session.status.isActivelyTraining {
                        Button("Delete", role: .destructive) {
                            onDeleteSet(set.id)
                        }
                    }
                }
        }
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
    }

    private var completedCount: Int {
        let ids = Set(sets.map(\.id))
        return session.completedSets.filter { ids.contains($0.plannedSetID) }.count
    }

    @ViewBuilder
    private func ledgerRow(index: Int, set: PlannedSet) -> some View {
        let completed = session.completedSets.first { $0.plannedSetID == set.id }
        let isCurrent = set.id == context.set.id

        if let completed {
            Button {
                onEditCompleted(completed)
            } label: {
                ledgerRowContent(
                    index: index,
                    set: set,
                    completed: completed,
                    isCurrent: isCurrent
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit-completed-set-\(index + 1)")
            .accessibilityHint("Opens the completed set editor")
        } else if isCurrent {
            Button(action: onEditCurrent) {
                ledgerRowContent(index: index, set: set, completed: nil, isCurrent: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("set-details")
            .accessibilityHint("Opens weight, reps, effort, and notes for this set")
        } else {
            ledgerRowContent(
                index: index,
                set: set,
                completed: nil,
                isCurrent: isCurrent
            )
            .accessibilityAction(named: "Skip set") {
                if session.status.isActivelyTraining { onDeleteSet(set.id) }
            }
        }
    }

    private func ledgerRowContent(
        index: Int,
        set: PlannedSet,
        completed: CompletedSet?,
        isCurrent: Bool
    ) -> some View {
        adaptiveLayout {
            Text("\(index + 1)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(isCurrent ? AppTheme.accentContent : AppTheme.contentTertiary)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    completed?.result.displayText
                        ?? draftResults[set.id]?.displayText
                        ?? session.resultOverride(for: set.id)?.displayText
                        ?? set.prescription.displayTarget
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(completed == nil ? AppTheme.contentSecondary : AppTheme.contentPrimary)
                if completed != nil,
                   let recorded = session.exerciseDefinition(for: set.id),
                   recorded.id != session.exerciseDefinition(for: context.set.id)?.id {
                    Text(recorded.name).font(.caption2).foregroundStyle(AppTheme.contentSecondary)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            if completed != nil {
                Label("Done", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentContent)
                    .accessibilityLabel("Completed")
            } else if isCurrent {
                Text("Current")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accentContent)
            } else {
                Text("Up next")
                    .font(.caption)
                    .foregroundStyle(AppTheme.contentTertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 88 : 52)
        .background(isCurrent ? AppTheme.accent.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
    }
}

private struct ExerciseRestEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let exerciseID: UUID
    @State private var secondsText: String
    @State private var isSaving = false

    init(exerciseID: UUID, initialSeconds: Int) {
        self.exerciseID = exerciseID
        _secondsText = State(initialValue: String(initialSeconds))
    }

    private var seconds: Int? {
        guard let value = Int(secondsText), (try? RestDuration(seconds: value)) != nil else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Applies after the remaining sets of this exercise in this workout, including any sets you add. Choose 0 to turn automatic rest off.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.contentSecondary)
                    HStack {
                        Text("Seconds")
                        TextField("Seconds", text: $secondsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Rest seconds")
                            .accessibilityIdentifier("default-rest-seconds")
                    }
                    .padding(16)
                    .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 18))

                    HStack {
                        ForEach([0, 60, 90, 120, 180], id: \.self) { value in
                            Button(value == 0 ? "Off" : "\(value)s") { secondsText = String(value) }
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityLabel(value == 0 ? "Turn automatic rest off" : "Rest \(value) seconds")
                        }
                    }
                    Button("Save rest time") {
                        guard let seconds else { return }
                        isSaving = true
                        Task {
                            if await model.setExerciseRest(exerciseID: exerciseID, seconds: seconds) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(seconds == nil || isSaving)
                    if let error = model.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(AppTheme.contentSecondary)
                    }
                }
                .padding(AppTheme.Spacing.screenInset)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Rest between sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .tint(AppTheme.accentContent)
    }
}

private struct SetEditorRequest: Identifiable {
    let id = UUID()
    let plannedSetID: UUID
    let completedSetID: UUID?
    let title: String
    let initialResult: SetResult
    let initialDetails: SetDetailsDraft
}

private struct ExerciseEffortPromptRequest: Identifiable {
    let id = UUID()
    let completedSetID: UUID
    let result: SetResult
    let notes: String?
    let exerciseName: String
}

private struct ExerciseEffortSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    let onAnswer: (Int?) async -> Bool
    @State private var isSaving = false
    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(exerciseName.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.action)
            Text("How many more reps could you have done?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Count only reps you could have done with good form.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.contentSecondary)

            HStack(spacing: 8) {
                ForEach(0...4, id: \.self) { value in
                    Button(value == 4 ? "4+" : "\(value)") { answer(value) }
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.contentPrimary)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16))
                        .buttonStyle(.plain)
                        .accessibilityLabel(value == 4 ? "Four or more reps left" : "\(value) reps left")
                }
            }

            Button("Skip for now") { answer(nil) }
                .buttonStyle(SecondaryActionButtonStyle())
            if saveFailed {
                Text("Your answer was not saved. Try again or skip for now.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .disabled(isSaving)
        .padding(AppTheme.Spacing.screenInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func answer(_ value: Int?) {
        isSaving = true
        Task {
            if await onAnswer(value) { dismiss() }
            else { saveFailed = true }
            isSaving = false
        }
    }
}

struct ActiveSetDraft {
    enum Kind {
        case weighted(MassUnit)
        case bodyweight
        case assisted(MassUnit)
        case amrap(MassUnit?)
        case timed(MassUnit?)
        case distance(DistanceUnit, includesDuration: Bool)
    }

    var kind: Kind
    private var optionalLoadUnit: MassUnit?
    var repsText: String
    var loadText: String
    var durationText: String
    var distanceText: String

    init(result: SetResult) {
        switch result {
        case let .weighted(reps, load):
            kind = .weighted(load.unit)
            repsText = String(reps.value)
            loadText = load.amount.inputText
            durationText = ""
            distanceText = ""
        case let .bodyweight(reps):
            kind = .bodyweight
            repsText = String(reps.value)
            loadText = ""
            durationText = ""
            distanceText = ""
        case let .assistedBodyweight(reps, assistance):
            kind = .assisted(assistance.unit)
            repsText = String(reps.value)
            loadText = assistance.amount.inputText
            durationText = ""
            distanceText = ""
        case let .amrap(reps, load):
            optionalLoadUnit = load?.unit
            kind = .amrap(load?.unit)
            repsText = String(reps.value)
            loadText = load?.amount.inputText ?? ""
            durationText = ""
            distanceText = ""
        case let .timed(duration, load):
            optionalLoadUnit = load?.unit
            kind = .timed(load?.unit)
            repsText = ""
            loadText = load?.amount.inputText ?? ""
            durationText = String(duration.seconds)
            distanceText = ""
        case let .distance(distance, duration):
            kind = .distance(distance.unit, includesDuration: duration != nil)
            repsText = ""
            loadText = ""
            durationText = duration.map { String($0.seconds) } ?? ""
            distanceText = distance.amount.inputText
        }
    }

    var includesOptionalLoad: Bool {
        switch kind {
        case let .amrap(unit), let .timed(unit): return unit != nil
        default: return false
        }
    }

    mutating func setOptionalLoad(_ included: Bool, unit: MassUnit) {
        let existingUnit: MassUnit?
        switch kind {
        case let .amrap(current), let .timed(current): existingUnit = current
        default: return
        }
        if included { optionalLoadUnit = existingUnit ?? optionalLoadUnit ?? unit }
        let selectedUnit = included ? optionalLoadUnit : nil
        switch kind {
        case .amrap: kind = .amrap(selectedUnit)
        case .timed: kind = .timed(selectedUnit)
        default: break
        }
        if included && loadText.isEmpty { loadText = "0" }
    }

    var includesOptionalDuration: Bool {
        if case let .distance(_, included) = kind { return included }
        return false
    }

    mutating func setOptionalDuration(_ included: Bool) {
        guard case let .distance(unit, _) = kind else { return }
        kind = .distance(unit, includesDuration: included)
        if included && durationText.isEmpty { durationText = "30" }
    }

    var result: SetResult? {
        switch kind {
        case let .weighted(unit):
            guard let reps = positiveInt(repsText), let amount = nonnegativeDecimal(loadText) else { return nil }
            return try? .weighted(reps: CompletedReps(reps), load: Load(amount: amount, unit: unit))
        case .bodyweight:
            guard let reps = positiveInt(repsText) else { return nil }
            return try? .bodyweight(reps: CompletedReps(reps))
        case let .assisted(unit):
            guard let reps = positiveInt(repsText), let amount = nonnegativeDecimal(loadText) else { return nil }
            return try? .assistedBodyweight(
                reps: CompletedReps(reps),
                assistance: Load(amount: amount, unit: unit)
            )
        case let .amrap(unit):
            guard let reps = positiveInt(repsText) else { return nil }
            let load: Load?
            if let unit {
                guard let amount = nonnegativeDecimal(loadText) else { return nil }
                load = try? Load(amount: amount, unit: unit)
            } else {
                load = nil
            }
            return try? .amrap(reps: CompletedReps(reps), load: load)
        case let .timed(unit):
            guard let seconds = positiveInt(durationText) else { return nil }
            let load: Load?
            if let unit {
                guard let amount = nonnegativeDecimal(loadText) else { return nil }
                load = try? Load(amount: amount, unit: unit)
            } else {
                load = nil
            }
            return try? .timed(duration: ExerciseDuration(seconds: seconds), load: load)
        case let .distance(unit, includesDuration):
            guard let amount = positiveDecimal(distanceText) else { return nil }
            let duration: ExerciseDuration?
            if includesDuration {
                guard let seconds = positiveInt(durationText) else { return nil }
                duration = try? ExerciseDuration(seconds: seconds)
            } else {
                duration = nil
            }
            return try? .distance(
                distance: ExerciseDistance(amount: amount, unit: unit),
                duration: duration
            )
        }
    }

    private func positiveInt(_ text: String) -> Int? {
        guard let value = Int(text), value > 0 else { return nil }
        return value
    }

    private func nonnegativeDecimal(_ text: String) -> Decimal? {
        guard let value = Decimal(string: text), value >= 0 else { return nil }
        return value
    }

    private func positiveDecimal(_ text: String) -> Decimal? {
        guard let value = Decimal(string: text), value > 0 else { return nil }
        return value
    }
}

private struct SetValueControls: View {
    @Binding var draft: ActiveSetDraft
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let compact: Bool

    @ViewBuilder
    var body: some View {
        switch draft.kind {
        case let .weighted(unit):
            paired(
                numberField("Weight", text: $draft.loadText, unit: unit.rawValue, id: "load", step: 5, minimum: 0),
                numberField("Reps", text: $draft.repsText, unit: "reps", id: "reps", step: 1, minimum: 1)
            )
        case .bodyweight:
            numberField("Reps", text: $draft.repsText, unit: "reps", id: "reps", step: 1, minimum: 1)
        case let .assisted(unit):
            paired(
                numberField("Assistance", text: $draft.loadText, unit: unit.rawValue, id: "load", step: 5, minimum: 0),
                numberField("Reps", text: $draft.repsText, unit: "reps", id: "reps", step: 1, minimum: 1)
            )
        case let .amrap(unit):
            if let unit {
                paired(
                    numberField("Weight", text: $draft.loadText, unit: unit.rawValue, id: "load", step: 5, minimum: 0),
                    numberField("Reps", text: $draft.repsText, unit: "reps", id: "reps", step: 1, minimum: 1)
                )
            } else {
                numberField("Reps", text: $draft.repsText, unit: "reps", id: "reps", step: 1, minimum: 1)
            }
        case let .timed(unit):
            if let unit {
                paired(
                    numberField("Duration", text: $draft.durationText, unit: "sec", id: "duration", step: 5, minimum: 1),
                    numberField("Weight", text: $draft.loadText, unit: unit.rawValue, id: "load", step: 5, minimum: 0)
                )
            } else {
                numberField("Duration", text: $draft.durationText, unit: "sec", id: "duration", step: 5, minimum: 1)
            }
        case let .distance(unit, includesDuration):
            if includesDuration {
                paired(
                    numberField("Distance", text: $draft.distanceText, unit: unit.rawValue, id: "distance", step: 0.1, minimum: 0.1),
                    numberField("Duration", text: $draft.durationText, unit: "sec", id: "duration", step: 5, minimum: 1)
                )
            } else {
                numberField("Distance", text: $draft.distanceText, unit: unit.rawValue, id: "distance", step: 0.1, minimum: 0.1)
            }
        }
    }

    private func paired<Leading: View, Trailing: View>(
        _ leading: Leading,
        _ trailing: Trailing
    ) -> some View {
        Group {
            if compact && !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 10) {
                    leading
                    trailing
                }
            } else {
                VStack(spacing: 12) {
                    leading
                    trailing
                }
            }
        }
    }

    private func numberField(
        _ title: String,
        text: Binding<String>,
        unit: String,
        id: String,
        step: Decimal,
        minimum: Decimal
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.medium))
                .tracking(0.8)
                .foregroundStyle(AppTheme.contentTertiary)
            HStack(spacing: 2) {
                Button {
                    adjust(text, by: -step, minimum: minimum)
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 19, weight: .semibold))
                }
                .buttonStyle(CompactStepperButtonStyle())
                .accessibilityLabel("Decrease \(title.lowercased())")
                .accessibilityIdentifier("decrease-set-\(id)")

                HStack(spacing: 3) {
                    TextField("0", text: text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(compact ? .body : .title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.contentPrimary)
                        .accessibilityLabel(title)
                        .accessibilityIdentifier("edit-set-\(id)")
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.contentTertiary)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)

                Button {
                    adjust(text, by: step, minimum: minimum)
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                }
                .buttonStyle(CompactStepperButtonStyle())
                .accessibilityLabel("Increase \(title.lowercased())")
                .accessibilityIdentifier("increase-set-\(id)")
            }
            .padding(.horizontal, 3)
            .frame(minHeight: 58)
            .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 19))
        }
        .foregroundStyle(AppTheme.contentPrimary)
    }

    private func adjust(_ binding: Binding<String>, by change: Decimal, minimum: Decimal) {
        let current = Decimal(string: binding.wrappedValue) ?? minimum
        binding.wrappedValue = max(minimum, current + change).inputText
    }
}

private struct InlineCurrentSetEditor: View {
    @State private var draft: ActiveSetDraft
    let onChange: (SetResult?) -> Void

    init(initialResult: SetResult, onChange: @escaping (SetResult?) -> Void) {
        _draft = State(initialValue: ActiveSetDraft(result: initialResult))
        self.onChange = onChange
    }

    var body: some View {
        SetValueControls(draft: updatingDraft, compact: true)
    }

    private var updatingDraft: Binding<ActiveSetDraft> {
        Binding(
            get: { draft },
            set: { updated in
                draft = updated
                onChange(updated.result)
            }
        )
    }
}

private struct ActiveSetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("trainingProfile.massUnit") private var unit = MassUnit.pounds
    let request: SetEditorRequest
    let onSave: (SetResult, SetDetailsDraft) async -> Bool
    @State private var draft: ActiveSetDraft
    @State private var details: SetDetailsDraft
    @State private var isSaving = false
    @State private var failed = false

    init(request: SetEditorRequest, onSave: @escaping (SetResult, SetDetailsDraft) async -> Bool) {
        self.request = request
        self.onSave = onSave
        _draft = State(initialValue: ActiveSetDraft(result: request.initialResult))
        _details = State(initialValue: request.initialDetails)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    optionalValues
                    SetValueControls(draft: $draft, compact: false)
                    SetDetailsFields(draft: $details)
                    Text(request.completedSetID == nil
                         ? "Applies only to this set. Tap Log set to save the result."
                         : "Updates only this recorded set. Your original planned target stays unchanged.")
                        .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    if failed { Text("The set could not be saved. Try again.").foregroundStyle(.red) }
                }
                .disabled(isSaving)
                .padding(AppTheme.Spacing.screenInset)
            }
            .safeAreaInset(edge: .bottom) {
                Button(request.completedSetID == nil ? "Use for this set" : "Save changes") {
                    guard let result = draft.result else { return }
                    isSaving = true
                    Task {
                        if await onSave(result, details) { dismiss() }
                        else { failed = true }
                        isSaving = false
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(draft.result == nil || isSaving)
                .padding(AppTheme.Spacing.screenInset)
                .background(AppTheme.background)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .tint(AppTheme.accentContent)
    }

    @ViewBuilder private var optionalValues: some View {
        switch draft.kind {
        case .amrap, .timed:
            Toggle("Include actual weight", isOn: Binding(
                get: { draft.includesOptionalLoad },
                set: { draft.setOptionalLoad($0, unit: unit) }
            )).accessibilityIdentifier("actual-include-load")
        case .distance:
            Toggle("Include actual duration", isOn: Binding(
                get: { draft.includesOptionalDuration },
                set: { draft.setOptionalDuration($0) }
            )).accessibilityIdentifier("actual-include-duration")
        default: EmptyView()
        }
    }
}

private struct ExerciseInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: ExerciseDefinition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let equipment = exercise.equipment {
                        Label(equipment, systemImage: "dumbbell.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.contentSecondary)
                    }

                    if let muscles = exercise.primaryMuscles, !muscles.isEmpty {
                        Text(muscles.joined(separator: " · "))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accentContent)
                    }

                    Text(exercise.description ?? "Technique instructions are not available for this exercise yet.")
                        .font(.body)
                        .foregroundStyle(AppTheme.contentPrimary)

                    Text("Form videos will be added here in a later release.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.contentTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Spacing.screenInset)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension WorkoutSession {
    func elapsedText(at date: Date) -> String {
        guard let startedAt = events.first(where: { event in
            if case .started = event.kind { return true }
            return false
        })?.occurredAt else { return "0:00" }

        var pausedAt: Date?
        var pausedDuration: TimeInterval = 0

        for event in events {
            switch event.kind {
            case .paused:
                pausedAt = event.occurredAt
            case .resumed, .finishPrepared:
                if let pauseStart = pausedAt {
                    pausedDuration += event.occurredAt.timeIntervalSince(pauseStart)
                    pausedAt = nil
                }
            default:
                break
            }
        }

        if let pausedAt {
            pausedDuration += date.timeIntervalSince(pausedAt)
        }

        let elapsed = max(0, Int(date.timeIntervalSince(startedAt) - pausedDuration))
        return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

}

private extension WorkoutSessionStatus {
    var isActivelyTraining: Bool {
        if case .active = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

private extension SetPrescription {
    var defaultResultForEditing: SetResult? {
        switch self {
        case let .weighted(reps, load):
            try? .weighted(reps: CompletedReps(reps.minimumValue), load: load)
        case let .bodyweight(reps):
            try? .bodyweight(reps: CompletedReps(reps.minimumValue))
        case let .assistedBodyweight(reps, assistance):
            try? .assistedBodyweight(
                reps: CompletedReps(reps.minimumValue),
                assistance: assistance
            )
        case let .amrap(load):
            try? .amrap(reps: CompletedReps(1), load: load)
        case let .timed(duration, load):
            .timed(duration: duration, load: load)
        case let .distance(distance, duration):
            .distance(distance: distance, duration: duration)
        }
    }
}

private extension RepTarget {
    var minimumValue: Int {
        switch self {
        case let .exact(value): value
        case let .range(lower, _): lower
        }
    }
}

private extension Decimal {
    var inputText: String {
        NSDecimalNumber(decimal: self).stringValue
    }
}

private extension SetPrescription {
    var displayTarget: String {
        switch self {
        case let .weighted(reps, load):
            "\(load.amount.formatted()) \(load.unit.rawValue) × \(reps.displayText)"
        case let .bodyweight(reps):
            "Bodyweight × \(reps.displayText)"
        case let .assistedBodyweight(reps, assistance):
            "−\(assistance.amount.formatted()) \(assistance.unit.rawValue) × \(reps.displayText)"
        case let .amrap(load):
            load.map { "\($0.amount.formatted()) \($0.unit.rawValue) · AMRAP" } ?? "AMRAP"
        case let .timed(duration, _):
            "\(duration.seconds) sec"
        case let .distance(distance, _):
            "\(distance.amount.formatted()) \(distance.unit.rawValue)"
        }
    }
}

private extension SetResult {
    var displayText: String {
        switch self {
        case let .weighted(reps, load):
            "\(load.amount.formatted()) \(load.unit.rawValue) × \(reps.value)"
        case let .bodyweight(reps):
            "Bodyweight × \(reps.value)"
        case let .assistedBodyweight(reps, assistance):
            "−\(assistance.amount.formatted()) \(assistance.unit.rawValue) × \(reps.value)"
        case let .amrap(reps, load):
            load.map { "\($0.amount.formatted()) \($0.unit.rawValue) × \(reps.value)" } ?? "\(reps.value) reps"
        case let .timed(duration, load):
            load.map { "\(duration.seconds) sec · \($0.amount.formatted()) \($0.unit.rawValue)" } ?? "\(duration.seconds) sec"
        case let .distance(distance, duration):
            duration.map { "\(distance.amount.formatted()) \(distance.unit.rawValue) · \($0.seconds) sec" }
                ?? "\(distance.amount.formatted()) \(distance.unit.rawValue)"
        }
    }
}

private extension RepTarget {
    var displayText: String {
        switch self {
        case let .exact(value): "\(value)"
        case let .range(lower, upper): "\(lower)–\(upper)"
        }
    }
}

private struct ExerciseReplacementPicker: View {
    @Environment(\.dismiss) private var dismiss
    let remainingSets: [PlannedSet]
    let onSelect: (ExerciseDefinition) async -> Bool
    @State private var query = ""
    @State private var isSaving = false
    @State private var failed = false

    private var visibleExercises: [CatalogExercise] {
        ExerciseCatalog.exercises.filter { exercise in
            remainingSets.allSatisfy { exercise.supportsReplacement(for: $0.prescription) }
                && (query.isEmpty || exercise.searchableText.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Only exercises compatible with all remaining set types are shown. Existing targets stay unchanged; review their values before logging. Completed sets keep their original exercise.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.contentSecondary)
                    if failed { Text("Could not save the replacement. Try again.").foregroundStyle(.red) }
                }
                if visibleExercises.isEmpty {
                    Text("No compatible exercises found. Try another search or keep the current movement.")
                        .foregroundStyle(AppTheme.contentSecondary)
                }
                ForEach(visibleExercises) { exercise in
                    Button {
                        isSaving = true
                        Task {
                            if await onSelect(exercise.definition) { dismiss() }
                            else { failed = true }
                            isSaving = false
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).foregroundStyle(AppTheme.contentPrimary)
                            Text(exercise.equipment).font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        }.frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("replace-exercise-\(exercise.id)")
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Replace exercise")
            .searchable(text: $query, prompt: "Search exercises")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(isSaving)
            } }
        }
        .interactiveDismissDisabled(isSaving)
        .tint(AppTheme.accentContent)
    }
}

extension CatalogExercise {
    func supportsReplacement(for prescription: SetPrescription) -> Bool {
        switch prescription {
        case .weighted:
            if case .weighted = modality { return true }
        case .bodyweight, .assistedBodyweight:
            if case .bodyweight = modality { return true }
        case let .amrap(load):
            if load == nil {
                if case .bodyweight = modality { return true }
            } else if case .weighted = modality { return true }
        case .timed:
            if case .timed = modality { return true }
        case .distance:
            // The current catalog's only distance-capable movement is Farmer Carry.
            // Isometric timed holds must not be suggested for distance targets.
            return id == 100
        }
        return false
    }
}
