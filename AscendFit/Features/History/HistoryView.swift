import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var filterByDate = false
    @State private var showsCalendar = false
    @State private var selectedDate = Date()

    private var visibleEntries: [WorkoutHistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.workoutHistory.filter { entry in
            let matchesDate = !filterByDate || Calendar.current.isDate(entry.summary.endedAt, inSameDayAs: selectedDate)
            let names = entry.session.plan.exercises.flatMap { exercise in
                (exercise.sets + entry.session.addedSets[exercise.id, default: []]).compactMap {
                    entry.session.exerciseDefinition(for: $0.id)?.name
                }
            }
            return matchesDate && (trimmed.isEmpty || entry.session.plan.title.localizedCaseInsensitiveContains(trimmed)
                || names.contains { $0.localizedCaseInsensitiveContains(trimmed) })
        }
    }

    var body: some View {
        let recordCounts = Dictionary(grouping: ExerciseProgress.all(in: model.workoutHistory).flatMap(\.records), by: { $0.performance.sessionID }).mapValues(\.count)
        List {
            if !model.workoutHistory.isEmpty {
                Section {
                    HistoryActivityStrip(history: model.workoutHistory, selectedDate: $selectedDate, filterByDate: $filterByDate)
                    NavigationLink {
                        ExerciseHistoryListView()
                    } label: {
                        Label("Exercise progress", systemImage: "chart.xyaxis.line")
                    }
                    .accessibilityIdentifier("exercise-progress")
                    Toggle("Choose a date", isOn: $showsCalendar)
                        .accessibilityIdentifier("history-date-filter")
                    if showsCalendar {
                        DatePicker("Workout date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .onChange(of: selectedDate) { _, _ in filterByDate = true }
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }
            if model.workoutHistory.isEmpty {
                ContentUnavailableView("No workouts yet", systemImage: "clock",
                    description: Text("Completed workouts will appear here. Build or import one from Today to get started."))
            } else if visibleEntries.isEmpty {
                ContentUnavailableView("No matching workouts", systemImage: "magnifyingglass",
                    description: Text("Try a different date or search."))
            } else {
                Section(filterByDate ? selectedDate.formatted(date: .abbreviated, time: .omitted) : "All workouts") {
                    ForEach(visibleEntries) { entry in
                        NavigationLink {
                            WorkoutHistoryDetailView(entry: entry)
                        } label: {
                            HistoryRow(entry: entry, recordCount: recordCounts[entry.id, default: 0])
                        }
                        .listRowBackground(AppTheme.surfacePrimary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("History")
        .searchable(text: $query, prompt: "Workout or exercise")
        .tint(AppTheme.accentContent)
        .task { await model.refreshHistory() }
        .toolbar {
            if !model.workoutHistory.isEmpty {
                Menu {
                    WorkoutExportActions(entries: model.workoutHistory)
                } label: {
                    Label("Export history", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("history-export")
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: WorkoutHistoryEntry
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.session.plan.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.contentPrimary)
                Spacer()
                Text(entry.summary.endedAt, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(AppTheme.contentTertiary)
            }

            Text(
                "\(entry.summary.activeDuration.shortDuration) · "
                    + "\(entry.summary.completedSetCount) sets · "
                    + entry.summary.volumeDescription
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(AppTheme.contentSecondary)
            if recordCount > 0 {
                Text("\(recordCount) new best\(recordCount == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accentContent)
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

private struct WorkoutHistoryDetailView: View {
    let entry: WorkoutHistoryEntry
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deletionFailed = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    metric("Duration", entry.summary.activeDuration.shortDuration)
                    metric("Completed", "\(entry.summary.completedSetCount) sets")
                }
                HStack(spacing: 10) {
                    metric("Modified", "\(entry.summary.modifiedSetCount)")
                    metric("Skipped", "\(entry.summary.skippedSetCount)")
                }
                metric("Volume", entry.summary.volumeDescription)
            }
            .listRowBackground(AppTheme.surfacePrimary)

            if let notes = entry.session.plan.notes {
                Section("Original workout instructions") {
                    Text(notes).foregroundStyle(AppTheme.contentPrimary)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }
            ForEach(entry.session.plan.exercises) { exercise in
                Section("\(exercise.exercise.name) · original plan") {
                    if let notes = exercise.notes {
                        Text(notes).font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    }
                    let sets = exercise.sets + entry.session.addedSets[exercise.id, default: []]
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        historySetRow(index: index, set: set)
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            if let notes = entry.summary.notes {
                Section("Workout notes") {
                    Text(notes)
                        .foregroundStyle(AppTheme.contentPrimary)
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            let records = ExerciseProgress.all(in: model.workoutHistory).flatMap(\.records).filter { $0.performance.sessionID == entry.id }
            if !records.isEmpty {
                Section("New bests") {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.performance.exercise.name).font(.headline)
                            Text("\(record.value.formatted()) \(record.unit) · \(record.label)")
                            Text("Previous best: \(record.previousBest.formatted()) \(record.unit)")
                                .font(.caption).foregroundStyle(AppTheme.contentSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .listRowBackground(AppTheme.surfacePrimary)
            }

            Section("Coach update") {
                Button {
                    UIPasteboard.general.string = model.coachReadyText(for: entry)
                    didCopy = true
                } label: {
                    Label(didCopy ? "Copied" : "Copy summary", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .accessibilityIdentifier("copy-coach-summary")

                ShareLink(item: model.coachReadyText(for: entry)) {
                    Label("Share coach update", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("share-coach-summary")
            }
            .foregroundStyle(AppTheme.accentContent)
            .listRowBackground(AppTheme.surfacePrimary)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            Menu {
                WorkoutExportActions(entries: [entry])
                Button("Delete workout", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("delete-workout")
            } label: {
                Label("Workout actions", systemImage: "ellipsis.circle")
            }
            .disabled(deleting)
            .accessibilityIdentifier("history-workout-actions")
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                deleting = true
                Task {
                    if await model.deleteWorkout(sessionID: entry.id) { dismiss() }
                    else { deletionFailed = true }
                    deleting = false
                }
            }
        } message: {
            Text("Its sets and notes will be removed from this device. This cannot be undone.")
        }
        .alert("Workout was not deleted", isPresented: $deletionFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your workout is still saved. Try again.")
        }
        .onAppear {
            if !model.workoutHistory.contains(where: { $0.id == entry.id }) { dismiss() }
        }
        .onChange(of: model.workoutHistory.map(\.id), initial: true) { _, ids in
            if !ids.contains(entry.id) { dismiss() }
        }
        .navigationTitle(entry.session.plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accentContent)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2)
                .tracking(0.8)
                .foregroundStyle(AppTheme.contentTertiary)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.contentPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historySetRow(index: Int, set: PlannedSet) -> some View {
        let completed = entry.session.completedSets.first { $0.plannedSetID == set.id }
        let wasSkipped = entry.session.skippedSetIDs.contains(set.id)

        return HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.contentTertiary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                if let exercise = entry.session.exerciseDefinition(for: set.id) {
                    Text(exercise.name).font(.caption).foregroundStyle(AppTheme.contentSecondary)
                }
                Text("\(set.role.rawValue) · \(set.side.rawValue)")
                    .font(.caption2).foregroundStyle(AppTheme.contentTertiary)
                if let completed {
                    Text(completed.result.summaryText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.contentPrimary)
                    if !set.prescription.matches(completed.result) {
                        Text("Planned \(set.prescription.summaryText)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.contentTertiary)
                    }
                    if let effort = completed.effort {
                        Text(effort.historyText).font(.caption).foregroundStyle(AppTheme.contentSecondary)
                    }
                    if let notes = completed.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(AppTheme.contentSecondary)
                    }
                } else {
                    Text(wasSkipped ? "Skipped" : "Not completed")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(wasSkipped ? AppTheme.contentSecondary : AppTheme.contentTertiary)
                    Text("Planned \(set.prescription.summaryText)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.contentTertiary)
                }
            }

            Spacer()

            Image(systemName: completed != nil ? "checkmark.circle.fill" : wasSkipped ? "forward.end.fill" : "circle")
                .foregroundStyle(completed != nil ? AppTheme.accentContent : AppTheme.contentTertiary)
        }
        .padding(.vertical, 3)
    }
}

private extension WorkoutSummary {
    var volumeDescription: String {
        guard !volumeByUnit.isEmpty else { return "No load volume" }
        return volumeByUnit
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\(NSDecimalNumber(decimal: $0.value).stringValue) \($0.key.rawValue)" }
            .joined(separator: " · ")
    }
}

private extension TimeInterval {
    var shortDuration: String {
        let minutes = max(0, Int(self) / 60)
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }
}

extension EffortTarget {
    var historyText: String {
        switch self {
        case let .rpe(value): "RPE \(value.value.formatted())"
        case let .rir(value): "\(value.value) RIR"
        }
    }
}
