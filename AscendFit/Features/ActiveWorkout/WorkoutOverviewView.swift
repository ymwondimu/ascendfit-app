import SwiftUI

struct WorkoutOverviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                if let session = model.activeSession {
                    Section {
                        Text("Choose an unfinished set to log next. After that set, the remaining workout order resumes, including superset and circuit rounds.")
                            .font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
                        if session.status != .active {
                            Text("Resume your workout or finish rest before choosing another set.")
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(AppTheme.surfacePrimary)
                    if let notes = session.plan.notes {
                        Section("Workout instructions") {
                            Text(notes).font(.subheadline).foregroundStyle(AppTheme.contentPrimary)
                        }
                        .listRowBackground(AppTheme.surfacePrimary)
                    }
                    ForEach(session.plan.exercises) { exercise in
                        Section(exercise.exercise.name) {
                            let sets = exercise.sets + session.addedSets[exercise.id, default: []]
                            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                let completed = session.completedSets.first { $0.plannedSetID == set.id }
                                let skipped = session.skippedSetIDs.contains(set.id)
                                let current = session.nextPendingSetID == set.id
                                Button {
                                    isSaving = true
                                    Task {
                                        if await model.selectNextSet(set.id) { dismiss() }
                                        else { failed = true }
                                        isSaving = false
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Set \(index + 1) · \(session.exerciseDefinition(for: set.id)?.name ?? exercise.exercise.name)")
                                                .font(.body.weight(.semibold))
                                            Text(completed?.result.summaryText ?? session.resultOverride(for: set.id)?.summaryText ?? set.prescription.summaryText)
                                                .font(.subheadline).foregroundStyle(AppTheme.contentSecondary)
                                            if let round = session.groupRound(for: set.id) {
                                                Text("\(exercise.group?.kind == .superset ? "Superset" : "Circuit") · Round \(round)")
                                                    .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                                            }
                                        }
                                        Spacer()
                                        Label(completed != nil ? "Done" : skipped ? "Skipped" : current ? "Current" : "Log next",
                                              systemImage: completed != nil ? "checkmark.circle.fill" : skipped ? "minus.circle" : current ? "circle.inset.filled" : "arrow.right.circle")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(current ? AppTheme.accentContent : AppTheme.contentPrimary)
                                    .frame(minHeight: 56)
                                    .accessibilityElement(children: .combine)
                                }
                                .disabled(isSaving || session.status != .active || completed != nil || skipped)
                                .accessibilityIdentifier("overview-set-\(session.plan.exercises.firstIndex { $0.id == exercise.id } ?? 0)-\(index + 1)")
                                .listRowBackground(AppTheme.surfacePrimary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Workout overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(isSaving) } }
            .alert("Could not select set", isPresented: $failed) {
                Button("OK", role: .cancel) { }
            } message: { Text(model.errorMessage ?? "Your workout is still saved. Try again.") }
        }
        .interactiveDismissDisabled(isSaving)
        .tint(AppTheme.accentContent)
    }
}
