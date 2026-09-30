import SwiftUI
import UIKit

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
        .fontDesign(.default)
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
                Text("ASCEND")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .tracking(-0.9)
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
        VStack(alignment: .leading, spacing: 18) {
            Text("TODAY'S SESSION")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.action)
            Text("Your next session starts here.")
                .font(.system(size: 38, weight: .semibold))
                .tracking(-1.4)
                .foregroundStyle(AppTheme.contentPrimary)

            Text("Bring in a workout from the coach you already trust.")
                .font(.body)
                .foregroundStyle(AppTheme.contentSecondary)

            VStack(spacing: 12) {
                Button("Import workout") {
                    presentedAction = .importWorkout
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button("Build manually") {
                    presentedAction = .buildManually
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(.top, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [AppTheme.surfaceSecondary, AppTheme.surfacePrimary], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private func plannedState(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 30)
                Text("TODAY'S SESSION")
                    .font(.caption.weight(.semibold)).tracking(1.1)
                    .foregroundStyle(AppTheme.action)
                Text(plan.title)
                    .font(.system(size: 42, weight: .semibold))
                    .tracking(-1.4)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(plan.exercises.count) exercises  /  \(plan.exercises.flatMap(\.sets).count) sets")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.82))
                Button("Start workout") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await model.startTodayWorkout() }
                }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(model.isStarting)
                    .padding(.top, 12)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .bottomLeading)
            .background {
                GeometryReader { geometry in
                    ZStack {
                        if plan.exercises.first?.exercise.name.caseInsensitiveCompare("Back Squat") == .orderedSame {
                            Image("CampaignSquat")
                                .resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } else {
                            LinearGradient(colors: [AppTheme.surfaceTertiary, AppTheme.surfacePrimary], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                        LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.72), .black.opacity(0.93)], startPoint: .top, endPoint: .bottom)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            if let notes = plan.notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.contentSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 18))
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("UP NEXT")
                    .font(.caption.weight(.medium))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.action)

                ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                    NavigationLink {
                        PlannedExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.title3.monospacedDigit().weight(.semibold))
                                .foregroundStyle(AppTheme.contentTertiary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.exercise.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.contentPrimary)
                                    .lineLimit(2)
                                Text(exercise.compactSummary)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(AppTheme.contentSecondary)
                                    .accessibilityIdentifier("today-exercise-summary-\(exercise.exercise.name)")
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.contentTertiary)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 74)
                        .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens set, weight, and rest details")
                }
            }

            Button("Import a different workout") { presentedAction = .importWorkout }
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
