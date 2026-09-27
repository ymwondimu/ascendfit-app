import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var presentedAction: TodayAction?
    @State private var sharedWaiting = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            header
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-share-host"),
               let text = ProcessInfo.processInfo.environment["ASCEND_FIT_UI_TEST_SHARED_TEXT"] {
                ShareLink("Share fixture", item: text)
            }
            if sharedWaiting {
                Button("Review shared workout", systemImage: "square.and.arrow.down") {
                    presentedAction = .importWorkout
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            if model.isRestoring {
                ProgressView("Restoring workouts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan = model.todayPlan {
                ScrollView {
                    plannedState(plan)
                        .padding(.bottom, AppTheme.Spacing.large)
                }
            } else {
                Spacer()
                emptyState
                Spacer()
            }
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.screenInset)
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               !ProcessInfo.processInfo.arguments.contains("--ui-testing-share-host"),
               let text = ProcessInfo.processInfo.environment["ASCEND_FIT_UI_TEST_SHARED_TEXT"] {
                _ = try? AppSharedWorkoutInbox.open().enqueue(text: text, sourceURL: nil)
            }
            refreshSharedInbox()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSharedInbox() }
        }
        .onChange(of: presentedAction) { _, action in
            if action == nil { refreshSharedInbox() }
        }
        .sheet(item: $presentedAction) { action in
            NavigationStack {
                switch action {
                case .buildManually:
                    ManualWorkoutBuilderView()
                        .environmentObject(model)
                case .settings:
                    SettingsView()
                case .importWorkout:
                    ImportWorkoutView().environmentObject(model)
                }
            }
        }
    }

    private func refreshSharedInbox() {
        sharedWaiting = (try? AppSharedWorkoutInbox.open().peek()) != nil
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.caption)
                    .foregroundStyle(AppTheme.contentTertiary)
                Text("Today")
                    .font(.largeTitle.bold())
                    .tracking(-0.7)
                    .foregroundStyle(AppTheme.contentPrimary)
            }

            Spacer()

            Button("Settings", systemImage: "person.crop.circle") {
                presentedAction = .settings
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(AppTheme.contentSecondary)
            .frame(width: 44, height: 44)
            .accessibilityHint("Opens settings")
        }
        .padding(.top, AppTheme.Spacing.small)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Text("Nothing on the bench yet.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.contentPrimary)
                .multilineTextAlignment(.center)

            Text("Bring in a workout from the coach you already trust.")
                .font(.body)
                .foregroundStyle(AppTheme.contentSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: AppTheme.Spacing.small) {
                Button("Import workout") {
                    presentedAction = .importWorkout
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button("Build manually") {
                    presentedAction = .buildManually
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(.top, AppTheme.Spacing.medium)
        }
        .frame(maxWidth: .infinity)
    }

    private func plannedState(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            Text("READY FOR TODAY")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text(plan.title)
                    .font(.largeTitle.bold())
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.contentPrimary)
                Text("\(plan.exercises.count) exercises · \(plan.exercises.flatMap(\.sets).count) sets")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.contentSecondary)
            }

            if let notes = plan.notes {
                Text(notes).font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
            }

            Button("Start workout") {
                Task { await model.startTodayWorkout() }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(model.isStarting)

            Button("Import a different workout", systemImage: "square.and.arrow.down") {
                presentedAction = .importWorkout
            }
            .frame(minHeight: 44)
            .foregroundStyle(AppTheme.accentContent)


            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("EXERCISES")
                    .font(.caption.weight(.medium))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.contentTertiary)

                ForEach(plan.exercises) { exercise in
                    NavigationLink {
                        PlannedExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack(spacing: 12) {
                            Text(exercise.exercise.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.contentPrimary)
                                .lineLimit(2)
                            Spacer()
                            Text(exercise.compactSummary)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(AppTheme.contentSecondary)
                                .multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("today-exercise-summary-\(exercise.exercise.name)")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.contentTertiary)
                        }
                        .padding(AppTheme.Spacing.medium)
                        .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens set, weight, and rest details")
                }
            }

            Button("Import another workout") { presentedAction = .importWorkout }
                .buttonStyle(SecondaryActionButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlannedExerciseDetailView: View {
    let exercise: PlannedExercise

    var body: some View {
        List {
            if exercise.exercise.description != nil || exercise.exercise.equipment != nil {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let equipment = exercise.exercise.equipment {
                            Label(equipment, systemImage: "dumbbell.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.contentTertiary)
                        }
                        if let description = exercise.exercise.description {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(AppTheme.contentSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            Section("Sets") {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.contentTertiary)
                            .frame(width: 24, alignment: .leading)
                        Text(set.prescription.compactTarget)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.contentPrimary)
                        Spacer()
                        if let rest = set.restAfter {
                            Text("\(rest.seconds)s rest")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.contentTertiary)
                        }
                    }
                    .frame(minHeight: 46)
                }
            }
            .listRowBackground(AppTheme.surfacePrimary)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(exercise.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(AppTheme.accentContent)
    }
}

private extension PlannedExercise {
    var compactSummary: String {
        let targets = Set(sets.map { $0.prescription.compactTarget })
        if targets.count == 1, let target = targets.first {
            return "\(sets.count) sets × \(target)"
        }
        return "\(sets.count) sets · varied"
    }
}

private extension SetPrescription {
    var compactTarget: String {
        switch self {
        case let .weighted(reps, load):
            if load.amount > 0 {
                return "\(reps.compactTarget) · \(load.amount.formatted()) \(load.unit.rawValue)"
            }
            return reps.compactTarget
        case let .bodyweight(reps):
            return "\(reps.compactTarget) · bodyweight"
        case let .assistedBodyweight(reps, assistance):
            return "\(reps.compactTarget) · −\(assistance.amount.formatted()) \(assistance.unit.rawValue)"
        case let .amrap(load):
            return load.map { "AMRAP · \($0.amount.formatted()) \($0.unit.rawValue)" } ?? "AMRAP"
        case let .timed(duration, load):
            return load.map { "\(duration.seconds) sec · \($0.amount.formatted()) \($0.unit.rawValue)" } ?? "\(duration.seconds) sec"
        case let .distance(distance, duration):
            let time = duration.map { " · \($0.seconds) sec" } ?? ""
            return "\(distance.amount.formatted()) \(distance.unit.rawValue)\(time)"
        }
    }
}

private extension RepTarget {
    var compactTarget: String {
        switch self {
        case let .exact(value): "\(value) reps"
        case let .range(lower, upper): "\(lower)–\(upper) reps"
        }
    }
}

private enum TodayAction: String, Identifiable {
    case importWorkout
    case buildManually
    case settings

    var id: String { rawValue }

}
